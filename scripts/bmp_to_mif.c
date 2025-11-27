/* This program translates a 24-bit-color bitmap (.bmp) file into a MIF file.
 *
 * 1. set COLS and ROWS to match the target memory
 * 2. set the COLOR_DEPTH to 3, 6, or 9
 * 3. Compile the code using WindowsMake.bat
 * 4. Run the program using
 *    ./bmp_to_mif.exe image.bmp COLS ROWS DEPTH
 *
 *    where image.bmp is any 24-bit-color bitmap image. The result is written to a new file
 *    called bmp_COLS_COLORDEPTH.mif. If the resolution of image.bmp is higher than
 *    COLS x ROWS, then the image will be scaled down appropriately. Also, the color
 *    will be scaled down from 24-bit to COLOR_DEPTH. If the original image has a lower
 *    resolution than COLS x ROWs, then the new image will be centered within the larger
 *    resolution, with the color depth still being scaled as needed.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int COLS = 640;
int ROWS = 480;
int COLOR_DEPTH = 9;
int RGB; // Will store color bits per channel (1 for 3-bit, 2 for 6-bit, 3 for 9-bit)

static FILE *fp;
char out_file_name[80];

int power(int base, int exp)
{
    if (exp == 0)
        return 1;
    else if (exp % 2)
        return base * power(base, exp - 1);
    else
    {
        int temp = power(base, exp / 2);
        return temp * temp;
    }
}

typedef unsigned char byte;

struct pixel
{
    byte b;
    byte g;
    byte r;
};

// Global variables for screen dimensions
int screen_x, screen_y;

// Read BMP file and extract the pixel values (store in data) and header (store in header)
// Data is data[0] = BLUE, data[1] = GREEN, data[2] = RED, data[3] = BLUE, etc...
int read_bmp(char *filename, byte **header, struct pixel **data, int *width_out, int *height_out)
{
    struct pixel *data_tmp;
    byte *header_tmp;
    FILE *file = fopen(filename, "rb");

    if (!file)
        return -1;

    // read the 54-byte header
    header_tmp = malloc(54 * sizeof(byte));
    fread(header_tmp, sizeof(byte), 54, file);

    // get height and width of image from the header
    *width_out = *(int *)(header_tmp + 18);  // width is a 32-bit int at offset 18
    *height_out = *(int *)(header_tmp + 22); // height is a 32-bit int at offset 22

    // Read in the image
    int size = (*width_out) * (*height_out);
    data_tmp = malloc(size * sizeof(struct pixel));
    fread(data_tmp, sizeof(struct pixel), size, file); // read the data
    fclose(file);

    *header = header_tmp;
    *data = data_tmp;

    return 0;
}

void write_pixel(int x, int y, int color)
{
    int address;
    address = y * COLS + x;
    fprintf(fp, "%d : %X;\n", address, color);
}

// Write the image to a MIF
void draw_image(struct pixel *data, int width, int height)
{
    int x, y, stride_x, stride_y, i, j, vga_x, vga_y;
    int r, g, b, R, G, B, color;

    fp = fopen(out_file_name, "w");
    fprintf(fp, "WIDTH=%d;\n", COLOR_DEPTH);
    fprintf(fp, "DEPTH=%d;\n\n", COLS * ROWS);
    fprintf(fp, "ADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\n\n");
    fprintf(fp, "CONTENT BEGIN\n");

    screen_x = COLS;
    screen_y = ROWS;

    // scale the image to fit the screen
    stride_x = (width > screen_x) ? width / screen_x : 1;
    stride_y = (height > screen_y) ? height / screen_y : 1;
    // scale proportionally (don't stretch the image)
    stride_y = (stride_x > stride_y) ? stride_x : stride_y;
    stride_x = (stride_y > stride_x) ? stride_y : stride_x;
    for (y = 0; y < height; y += stride_y)
    {
        for (x = 0; x < width; x += stride_x)
        {
            // find the average of the pixels being scaled down to the VGA resolution
            r = 0;
            g = 0;
            b = 0;
            for (i = 0; i < stride_y; i++)
            {
                for (j = 0; j < stride_x; ++j)
                {
                    r += data[(y + i) * width + (x + j)].r;
                    g += data[(y + i) * width + (x + j)].g;
                    b += data[(y + i) * width + (x + j)].b;
                }
            }
            r = r / (stride_x * stride_y);
            g = g / (stride_x * stride_y);
            b = b / (stride_x * stride_y);

            // each of r, g, b is an 8-bit value. Convert to the right color-depth
            if (RGB == 1)
            {
                R = r > 127 ? 1 : 0;
                G = g > 127 ? 1 : 0;
                B = b > 127 ? 1 : 0;
            }
            else if (RGB == 2)
            {
                R = r > 191 ? 3 : (r > 127 ? 2 : (r > 63 ? 1 : 0));
                G = g > 191 ? 3 : (g > 127 ? 2 : (g > 63 ? 1 : 0));
                B = b > 191 ? 3 : (b > 127 ? 2 : (b > 63 ? 1 : 0));
            }
            else if (RGB == 3)
            {
                R = r > 223 ? 7 : (r > 191 ? 6 : (r > 159 ? 5 : (r > 127 ? 4 : (r > 95 ? 3 : (r > 63 ? 2 : (r > 31 ? 1 : 0))))));
                G = g > 223 ? 7 : (g > 191 ? 6 : (g > 159 ? 5 : (g > 127 ? 4 : (g > 95 ? 3 : (g > 63 ? 2 : (g > 31 ? 1 : 0))))));
                B = b > 223 ? 7 : (b > 191 ? 6 : (b > 159 ? 5 : (b > 127 ? 4 : (b > 95 ? 3 : (b > 63 ? 2 : (b > 31 ? 1 : 0))))));
            }
            // now write the pixel color to the MIF
            color = (R << RGB * 2) | (G << RGB) | B;
            vga_x = x / stride_x;
            vga_y = y / stride_y;
            if (screen_x > width / stride_x) // center if needed
                write_pixel(vga_x + (screen_x - (width / stride_x)) / 2, (screen_y - 1) - vga_y, color);
            else if ((vga_x < screen_x) && (vga_y < screen_y))
                write_pixel(vga_x, (screen_y - 1) - vga_y, color);
        }
    }
    fprintf(fp, "END;\n");
    fclose(fp);
}

int main(int argc, char *argv[])
{
    struct pixel *image;
    byte *header;
    int width, height;

    // Check inputs
    if (argc < 2)
    {
        printf("Usage: bmp_to_mif <BMP filename> [-c COLS] [-r ROWS] [-d DEPTH]\n");
        return 0;
    }

    // Open input image file (24-bit bitmap image)
    if (read_bmp(argv[1], &header, &image, &width, &height) < 0)
    {
        printf("Failed to read BMP\n");
        return 0;
    }

    // Create output filename based on input name and color depth
    char *input_name = argv[1];
    char *dot = strrchr(input_name, '.');
    if (dot)
    {
        int base_len = dot - input_name;
        snprintf(out_file_name, sizeof(out_file_name), "%.*s_%d_%d.mif",
                 base_len, input_name, COLS, COLOR_DEPTH);
    }
    else
    {
        snprintf(out_file_name, sizeof(out_file_name), "%s_%d_%d.mif",
                 input_name, COLS, COLOR_DEPTH);
    }
    // Iterate through command-line arguments, starting from index 2 (after bitmap filename)
    for (int i = 2; i < argc; i++)
    {
        // Check for optional arguments
        if (strcmp(argv[i], "-c") == 0)
        {
            // Check if there's a subsequent argument for columns
            if (i + 1 < argc)
            {
                COLS = atoi(argv[i + 1]);
                i++; // Skip the next argument as it's part of this option
            }
            else
            {
                fprintf(stderr, "Error: -c requires an argument.\n");
                return 1; // Indicate error
            }
        }
        else if (strcmp(argv[i], "-r") == 0)
        {
            // Check if there's a subsequent argument for rows
            if (i + 1 < argc)
            {
                ROWS = atoi(argv[i + 1]);
                i++; // Skip the next argument as it's part of this option
            }
            else
            {
                fprintf(stderr, "Error: -r requires an argument.\n");
                return 1; // Indicate error
            }
        }
        else if (strcmp(argv[i], "-d") == 0)
        {
            // Check if there's a subsequent argument for color depth
            if (i + 1 < argc)
            {
                COLOR_DEPTH = atoi(argv[i + 1]);
                // Validate color depth (must be 3, 6, or 9)
                if (COLOR_DEPTH != 3 && COLOR_DEPTH != 6 && COLOR_DEPTH != 9)
                {
                    fprintf(stderr, "Error: Color depth must be 3, 6, or 9.\n");
                    return 1;
                }
                // Set RGB based on color depth
                RGB = COLOR_DEPTH / 3;
                i++; // Skip the next argument as it's part of this option
            }
            else
            {
                fprintf(stderr, "Error: -d requires an argument.\n");
                return 1; // Indicate error
            }
        }
        else
        {
            // Handle other arguments or non-recognized options
            printf("Unrecognized argument: %s\n", argv[i]);
        }
    }
    screen_x = COLS;
    screen_y = ROWS;
    RGB = COLOR_DEPTH / 3;

    sprintf(out_file_name, "bmp_%d_%d.mif", COLS, COLOR_DEPTH);
    draw_image(image, width, height);
    printf("Read bitmap file %s, wrote (%d x %d x %d) MIF to file %s\n", argv[1],
           COLS, ROWS, COLOR_DEPTH, out_file_name);

    return 0;
}
