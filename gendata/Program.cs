/*
 * Vertical text data generator
 * By Ralakimus 2021
 */

using System;
using System.Drawing;
using System.IO;

namespace GenVertiTextData
{
    class Program
    {
        // Convert 8-bit color to MD color
        static int ConvColor(int inColor)
        {
            int[] mdColors = { 0, 52, 87, 116, 144, 172, 206, 255 };

            int i;
            for (i = 0; i < mdColors.Length; ++i)
            {
                if (inColor <= mdColors[i])
                {
                    if (i == 0)
                        return 0;
                    else
                    {
                        if ((mdColors[i] - inColor) < (inColor - mdColors[i - 1]))
                            return i * 2;
                        else
                            return (i - 1) * 2;
                    }
                }
            }

            return 0;
        }
        
        // Main program
        static void Main(string[] args)
        {
            if (args.Length > 0)
            {
                using (Bitmap bmp = (Bitmap)Image.FromFile(args[0]))
                {
                    // Get image width
                    int width = bmp.Width;
                    if (width > 20)
                    {
                        Console.WriteLine("Warning: Image width is greater than maximum possible width. " +
                            "Converted data will be cropped.");
                        width = 20;
                    }

                    // Convert image
                    using (StreamWriter sw = File.CreateText(Path.GetFileNameWithoutExtension(args[0]) + ".asm"))
                    {
                        for (int y = 0; y < bmp.Height; ++y)
                        {
                            sw.Write("\tLN_DATA\t");
                            for (int x = 0; x < width; ++x)
                            {
                                Color col = bmp.GetPixel(x, y);
                                sw.Write($"${ConvColor(col.B).ToString("X")}{ConvColor(col.G).ToString("X")}{ConvColor(col.R).ToString("X")}");
                                if (x < width - 1)
                                    sw.Write(", ");
                                else
                                    sw.Write("\n");
                            }
                        }
                    }
                }
            }
            else
            {
                // No input file specified
                Console.WriteLine(
                    $"USAGE: GenVertiTextData input\n\n" +
                    $"input - Input image file");
            }
        }
    }
}
