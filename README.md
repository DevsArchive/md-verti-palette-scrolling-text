# Veritcal palette scrolling text demo for Sega Genesis/Mega Drive
An old, well known trick. Updates the palette on each line of a base image to draw an image to draw text (or really anything).
The formation of the base image will affect whatever is drawn, which can be used for some neat effects.

Have fun... or else!

## Why the hell are you not using horizontal interrupts?
Because they are too slow. No matter how optimal I make the palette updating code, the interrupt itself takes too long, which makes
the palette update bleed into when the screen begins drawing again, which then causes CRAM dots. So, I opted to manually check when an H-BLANK
period is about to start, and then immediately update the palette.

This is actually exactly how the moose chase section in Mickey Mania does the floor rendering.

## Why do you set and clear the display flag repeatedly?
DMAs are much quicker when the display flag is clear.