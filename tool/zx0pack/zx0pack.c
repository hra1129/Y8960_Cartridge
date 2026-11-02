/*
 * zx0pack - Y8960 update image packer/unpacker (ZX0 block compression format v1)
 *
 *   Pack:   zx0pack <header.bin> <payload.bin> <output>
 *           Reads the 48-byte update header and the raw payload, and writes a
 *           compressed update image: header (with format marker byte 31 set
 *           to 1) + subheader (uint32 LE original size, uint16 LE block size)
 *           + one frame per 16384-byte block. Each frame is a uint16 LE word
 *           W followed by W bytes: a ZX0 stream, or, when W has bit 15 set, a
 *           stored (uncompressed) block of W & 0x7FFF bytes.
 *   Unpack: zx0pack -u <image> <payload_out>
 *           Accepts both raw (marker 0) and compressed (marker 1) images and
 *           writes the original payload.
 *
 * The ZX0 compressor used here is the official implementation by
 * Einar Saukas (BSD 3-Clause License, see LICENSE-zx0.txt and zx0/).
 * The ZX0 decompressor below is a strict in-memory port of the reference
 * decompressor dzx0.c by Einar Saukas (BSD 3-Clause License).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zx0/zx0.h"

#define HEADER_SIZE   48
#define MARKER_OFFSET 31
#define BLOCK_SIZE    16384
#define MAX_OFFSET_ZX0 32640

/* ------------------------------------------------------------------ */
/* small helpers                                                      */
/* ------------------------------------------------------------------ */

static void die(const char *message, const char *name) {
    if (name)
        fprintf(stderr, "zx0pack: %s: %s\n", message, name);
    else
        fprintf(stderr, "zx0pack: %s\n", message);
    exit(1);
}

static unsigned char *read_entire_file(const char *path, size_t *size_out) {
    FILE *fp = fopen(path, "rb");
    long size;
    unsigned char *data;

    if (!fp)
        die("cannot open input file", path);
    if (fseek(fp, 0L, SEEK_END) != 0)
        die("cannot seek in input file", path);
    size = ftell(fp);
    if (size < 0)
        die("cannot determine size of input file", path);
    if (fseek(fp, 0L, SEEK_SET) != 0)
        die("cannot seek in input file", path);
    data = (unsigned char *)malloc(size > 0 ? (size_t)size : 1);
    if (!data)
        die("insufficient memory", NULL);
    if (size > 0 && fread(data, 1, (size_t)size, fp) != (size_t)size)
        die("cannot read input file", path);
    fclose(fp);
    *size_out = (size_t)size;
    return data;
}

static void write_entire_file(const char *path, const unsigned char *data, size_t size) {
    FILE *fp = fopen(path, "wb");

    if (!fp)
        die("cannot create output file", path);
    if (size > 0 && fwrite(data, 1, size, fp) != size)
        die("cannot write output file", path);
    if (fclose(fp) != 0)
        die("cannot write output file", path);
}

/* Validate the signature field of a 48-byte update header: a non-empty
 * printable ASCII text followed by 00h padding up to byte 30.
 * Returns the signature text length, or -1 if the field is malformed. */
static int check_signature_field(const unsigned char *header) {
    int i;

    for (i = 0; i <= 30; i++) {
        if (header[i] == 0)
            break;
        if (header[i] < 0x20 || header[i] > 0x7E)
            return -1;
    }
    if (i == 0)
        return -1;                      /* empty signature text */
    for (; i <= 30; i++) {
        if (header[i] != 0)
            return -1;                  /* padding must stay 00h */
    }
    return 0;
}

static unsigned int get_u16le(const unsigned char *p) {
    return (unsigned int)p[0] | ((unsigned int)p[1] << 8);
}

static unsigned long get_u32le(const unsigned char *p) {
    return (unsigned long)p[0] | ((unsigned long)p[1] << 8) |
           ((unsigned long)p[2] << 16) | ((unsigned long)p[3] << 24);
}

static void put_u16le(unsigned char *p, unsigned int value) {
    p[0] = (unsigned char)(value & 0xFF);
    p[1] = (unsigned char)((value >> 8) & 0xFF);
}

static void put_u32le(unsigned char *p, unsigned long value) {
    p[0] = (unsigned char)(value & 0xFF);
    p[1] = (unsigned char)((value >> 8) & 0xFF);
    p[2] = (unsigned char)((value >> 16) & 0xFF);
    p[3] = (unsigned char)((value >> 24) & 0xFF);
}

/* ------------------------------------------------------------------ */
/* ZX0 decompressor (in-memory port of dzx0.c by Einar Saukas)        */
/* ------------------------------------------------------------------ */

typedef struct {
    const unsigned char *in;
    size_t in_len;
    size_t in_pos;
    unsigned char *out;
    size_t out_len;                     /* expected output length */
    size_t out_pos;
    int bit_mask;
    int bit_value;
    int backtrack;
    int last_byte;
    int last_offset;
    int error;
} zx0_decoder;

static int zx0_read_byte(zx0_decoder *d) {
    if (d->in_pos >= d->in_len) {
        d->error = 1;
        return 0;
    }
    d->last_byte = d->in[d->in_pos++];
    return d->last_byte;
}

static int zx0_read_bit(zx0_decoder *d) {
    if (d->backtrack) {
        d->backtrack = 0;
        return d->last_byte & 1;
    }
    d->bit_mask >>= 1;
    if (d->bit_mask == 0) {
        d->bit_mask = 128;
        d->bit_value = zx0_read_byte(d);
        if (d->error)
            return 0;
    }
    return (d->bit_value & d->bit_mask) ? 1 : 0;
}

static int zx0_read_elias_gamma(zx0_decoder *d, int inverted) {
    int value = 1;

    while (!zx0_read_bit(d)) {
        if (d->error)
            return 0;
        value = (value << 1) | (zx0_read_bit(d) ^ inverted);
        if (d->error || value > 0x20000) {
            d->error = 1;
            return 0;
        }
    }
    return value;
}

static void zx0_copy_from_offset(zx0_decoder *d, int offset, int length) {
    int i;

    if (offset <= 0 || (size_t)offset > d->out_pos ||
        (size_t)length > d->out_len - d->out_pos) {
        d->error = 1;
        return;
    }
    for (i = 0; i < length; i++) {
        d->out[d->out_pos] = d->out[d->out_pos - (size_t)offset];
        d->out_pos++;
    }
}

/* Decompress one independent ZX0 stream. The stream must produce exactly
 * out_len bytes and be consumed exactly. Returns 0 on success. */
static int zx0_decompress(const unsigned char *in, size_t in_len,
                          unsigned char *out, size_t out_len) {
    zx0_decoder d;
    int mode = 0;                       /* 0: literals, 1: last offset, 2: new offset */

    memset(&d, 0, sizeof(d));
    d.in = in;
    d.in_len = in_len;
    d.out = out;
    d.out_len = out_len;
    d.last_offset = INITIAL_OFFSET;

    for (;;) {
        if (mode == 0) {                /* copy literals */
            int length = zx0_read_elias_gamma(&d, FALSE);
            int i;
            if (d.error)
                return -1;
            if ((size_t)length > out_len - d.out_pos)
                return -1;
            for (i = 0; i < length; i++) {
                int b = zx0_read_byte(&d);
                if (d.error)
                    return -1;
                d.out[d.out_pos++] = (unsigned char)b;
            }
            mode = zx0_read_bit(&d) ? 2 : 1;
            if (d.error)
                return -1;
        } else if (mode == 1) {         /* copy from last offset */
            int length = zx0_read_elias_gamma(&d, FALSE);
            if (d.error)
                return -1;
            zx0_copy_from_offset(&d, d.last_offset, length);
            if (d.error)
                return -1;
            mode = zx0_read_bit(&d) ? 2 : 0;
            if (d.error)
                return -1;
        } else {                        /* copy from new offset */
            int offset_msb = zx0_read_elias_gamma(&d, TRUE);
            int length;
            if (d.error)
                return -1;
            if (offset_msb == 256)
                break;                  /* end marker */
            if (offset_msb > 256)
                return -1;
            d.last_offset = offset_msb * 128 - (zx0_read_byte(&d) >> 1);
            if (d.error || d.last_offset <= 0)
                return -1;
            d.backtrack = 1;
            length = zx0_read_elias_gamma(&d, FALSE) + 1;
            if (d.error)
                return -1;
            zx0_copy_from_offset(&d, d.last_offset, length);
            if (d.error)
                return -1;
            mode = zx0_read_bit(&d) ? 2 : 0;
            if (d.error)
                return -1;
        }
    }

    if (d.out_pos != out_len)
        return -1;
    if (d.in_pos != in_len)
        return -1;
    return 0;
}

/* ------------------------------------------------------------------ */
/* pack                                                               */
/* ------------------------------------------------------------------ */

static void do_pack(const char *header_path, const char *payload_path,
                    const char *output_path) {
    unsigned char header[HEADER_SIZE];
    unsigned char subheader[6];
    unsigned char *header_data;
    unsigned char *payload;
    size_t header_size;
    size_t payload_size;
    size_t produced = 0;
    size_t output_size = 0;
    int zx0_blocks = 0;
    int stored_blocks = 0;
    FILE *ofp;

    header_data = read_entire_file(header_path, &header_size);
    if (header_size != HEADER_SIZE)
        die("header file must be exactly 48 bytes", header_path);
    memcpy(header, header_data, HEADER_SIZE);
    free(header_data);
    if (check_signature_field(header) != 0)
        die("malformed signature field in header file", header_path);
    if (header[MARKER_OFFSET] != 0)
        die("header file already has a format marker (byte 31 != 0)", header_path);
    header[MARKER_OFFSET] = 1;

    payload = read_entire_file(payload_path, &payload_size);
    if (payload_size == 0)
        die("payload file is empty", payload_path);
    if (payload_size > 0xFFFFFFFFUL)
        die("payload file is too large", payload_path);

    ofp = fopen(output_path, "wb");
    if (!ofp)
        die("cannot create output file", output_path);

    if (fwrite(header, 1, HEADER_SIZE, ofp) != HEADER_SIZE)
        die("cannot write output file", output_path);
    output_size += HEADER_SIZE;

    put_u32le(subheader, (unsigned long)payload_size);
    put_u16le(subheader + 4, BLOCK_SIZE);
    if (fwrite(subheader, 1, 6, ofp) != 6)
        die("cannot write output file", output_path);
    output_size += 6;

    while (produced < payload_size) {
        size_t block_len = payload_size - produced;
        unsigned char *block_data;
        int block_zx0_size;
        int delta;

        if (block_len > BLOCK_SIZE)
            block_len = BLOCK_SIZE;

        block_data = compress(
            optimize(payload + produced, (int)block_len, 0, MAX_OFFSET_ZX0),
            payload + produced, (int)block_len, 0, FALSE, TRUE,
            &block_zx0_size, &delta);

        if (block_zx0_size >= (int)block_len) {
            /* stored form: no gain from compression */
            unsigned char word[2];
            put_u16le(word, 0x8000u | (unsigned int)block_len);
            if (fwrite(word, 1, 2, ofp) != 2 ||
                fwrite(payload + produced, 1, block_len, ofp) != block_len)
                die("cannot write output file", output_path);
            output_size += 2 + block_len;
            stored_blocks++;
        } else {
            unsigned char word[2];
            put_u16le(word, (unsigned int)block_zx0_size);
            if (fwrite(word, 1, 2, ofp) != 2 ||
                fwrite(block_data, 1, (size_t)block_zx0_size, ofp) != (size_t)block_zx0_size)
                die("cannot write output file", output_path);
            output_size += 2 + (size_t)block_zx0_size;
            zx0_blocks++;
        }
        free(block_data);
        produced += block_len;
    }

    if (fclose(ofp) != 0)
        die("cannot write output file", output_path);
    free(payload);

    printf("zx0pack: payload %lu bytes -> image %lu bytes (%.1f%%), "
           "%d ZX0 blocks, %d stored blocks\n",
           (unsigned long)payload_size, (unsigned long)output_size,
           100.0 * (double)output_size / (double)payload_size,
           zx0_blocks, stored_blocks);
}

/* ------------------------------------------------------------------ */
/* unpack                                                             */
/* ------------------------------------------------------------------ */

static void do_unpack(const char *image_path, const char *payload_path) {
    unsigned char *image;
    unsigned char *payload;
    size_t image_size;
    size_t payload_size;

    image = read_entire_file(image_path, &image_size);
    if (image_size < HEADER_SIZE)
        die("image file is smaller than the 48-byte header", image_path);
    if (check_signature_field(image) != 0)
        die("malformed signature field in image file", image_path);

    if (image[MARKER_OFFSET] == 0) {
        /* raw (legacy) image: payload follows the header */
        payload_size = image_size - HEADER_SIZE;
        if (payload_size == 0)
            die("image file has an empty payload", image_path);
        write_entire_file(payload_path, image + HEADER_SIZE, payload_size);
        printf("zx0pack: raw image, payload %lu bytes written\n",
               (unsigned long)payload_size);
    } else if (image[MARKER_OFFSET] == 1) {
        /* compressed image: subheader + frames */
        unsigned long original_size;
        unsigned int block_size;
        size_t pos = HEADER_SIZE + 6;
        size_t produced = 0;

        if (image_size < HEADER_SIZE + 6)
            die("compressed image is truncated (no subheader)", image_path);
        original_size = get_u32le(image + HEADER_SIZE);
        block_size = get_u16le(image + HEADER_SIZE + 4);
        if (original_size == 0)
            die("compressed image has an invalid original size of 0", image_path);
        if (block_size != BLOCK_SIZE)
            die("compressed image has an unsupported block size", image_path);

        payload = (unsigned char *)malloc(original_size);
        if (!payload)
            die("insufficient memory", NULL);

        while (produced < original_size) {
            size_t expected = original_size - produced;
            unsigned int word;
            unsigned int frame_len;

            if (expected > block_size)
                expected = block_size;
            if (pos + 2 > image_size)
                die("compressed image is truncated (frame word)", image_path);
            word = get_u16le(image + pos);
            pos += 2;
            if (word & 0x8000u) {
                frame_len = word & 0x7FFFu;
                if (frame_len != expected)
                    die("stored block length does not match the expected block length", image_path);
                if (pos + frame_len > image_size)
                    die("compressed image is truncated (stored block)", image_path);
                memcpy(payload + produced, image + pos, frame_len);
                pos += frame_len;
            } else {
                frame_len = word;
                if (frame_len == 0 || frame_len > BLOCK_SIZE)
                    die("ZX0 frame has an invalid length", image_path);
                if (pos + frame_len > image_size)
                    die("compressed image is truncated (ZX0 frame)", image_path);
                if (zx0_decompress(image + pos, frame_len,
                                   payload + produced, expected) != 0)
                    die("ZX0 decompression failed", image_path);
                pos += frame_len;
            }
            produced += expected;
        }
        if (pos != image_size)
            die("compressed image has trailing bytes after the last frame", image_path);

        write_entire_file(payload_path, payload, original_size);
        free(payload);
        printf("zx0pack: compressed image, payload %lu bytes written\n",
               original_size);
    } else {
        die("unknown format marker (byte 31) in image file", image_path);
    }

    free(image);
}

/* ------------------------------------------------------------------ */

int main(int argc, char *argv[]) {
    if (argc == 4 && strcmp(argv[1], "-u") == 0) {
        do_unpack(argv[2], argv[3]);
        return 0;
    }
    if (argc == 4 && argv[1][0] != '-') {
        do_pack(argv[1], argv[2], argv[3]);
        return 0;
    }
    fprintf(stderr,
            "Usage: %s <header.bin> <payload.bin> <output>\n"
            "       %s -u <image> <payload_out>\n",
            argv[0], argv[0]);
    return 1;
}
