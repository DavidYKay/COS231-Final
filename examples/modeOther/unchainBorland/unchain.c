/**************************************************************************
 * unchain.c                                                              *
 * written by David Brackeen                                              *
 * http://www.brackeen.com/home/vga/                                      *
 *                                                                        *
 * This is a 16-bit program.                                              *
 * Tab stops are set to 2.                                                *
 * Remember to compile in the LARGE memory model!                         *
 * To compile in Borland C: bcc -ml unchain.c                             *
 *                                                                        *
 * This program will only work on DOS- or Windows-based systems with a    *
 * VGA, SuperVGA or compatible video adapter.                             *
 *                                                                        *
 * Please feel free to copy this source code.                             *
 *                                                                        *
 * DESCRIPTION: This program demonstrates VGA's unchained mode            *
 **************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <dos.h>
#include <mem.h>


#define VIDEO_INT           0x10      /* the BIOS video interrupt. */
#define SET_MODE            0x00      /* BIOS func to set the video mode. */
#define VGA_256_COLOR_MODE  0x13      /* use to set 256-color mode. */
#define TEXT_MODE           0x03      /* use to set 80x25 text mode. */


#define SC_INDEX            0x03c4    /* VGA sequence controller */
#define SC_DATA             0x03c5
#define PALETTE_INDEX       0x03c8    /* VGA digital-to-analog converter */
#define PALETTE_DATA        0x03c9
#define GC_INDEX            0x03ce    /* VGA graphics controller */
#define GC_DATA             0x03cf
#define CRTC_INDEX          0x03d4    /* VGA CRT controller */
#define CRTC_DATA           0x03d5
#define INPUT_STATUS_1      0x03da

#define MAP_MASK            0x02      /* Sequence controller registers */
#define ALL_PLANES          0xff02
#define MEMORY_MODE         0x04

#define LATCHES_ON          0x0008    /* Graphics controller registers */
#define LATCHES_OFF         0xff08

#define HIGH_ADDRESS        0x0C      /* CRT controller registers */
#define LOW_ADDRESS         0x0D
#define UNDERLINE_LOCATION  0x14
#define MODE_CONTROL        0x17

#define DISPLAY_ENABLE      0x01      /* VGA input status bits */
#define VRETRACE            0x08

#define SCREEN_WIDTH        320       /* width in pixels of mode 0x13 */
#define SCREEN_HEIGHT       200       /* height in pixels of mode 0x13 */
#define SCREEN_SIZE         (word)(SCREEN_WIDTH*SCREEN_HEIGHT)
#define NUM_COLORS          256       /* number of colors in mode 0x13 */

#define BITMAP_WIDTH        32
#define BITMAP_HEIGHT       25
#define ANIMATION_FRAMES    24
#define TOTAL_FRAMES        140
#define VERTICAL_RETRACE              /* comment out this line for more
                                         accurate timing */
typedef unsigned char  byte;
typedef unsigned short word;
typedef unsigned long  dword;

byte *VGA=(byte *)0xA0000000L;        /* this points to video memory. */
word *my_clock=(word *)0x0000046C;    /* this points to the 18.2hz system
										 clock. */

typedef struct tagBITMAP              /* the structure for a bitmap. */
{
	word width;
	word height;
	byte palette[256*3];
	byte *data;
} BITMAP;

typedef struct tagOBJECT              /* the structure for a moving object
										 in 2d space; used for animation */
{
	int x,y;
	int dx,dy;
	byte width,height;
} OBJECT;

/**************************************************************************
 *  fskip                                                                 *
 *     Skips bytes in a file.                                             *
 **************************************************************************/

void fskip(FILE *fp, int num_bytes)
{
	int i;
	for (i=0; i<num_bytes; i++)
		fgetc(fp);
}

/**************************************************************************
 *  set_mode                                                              *
 *     Sets the video mode.                                               *
 **************************************************************************/

void set_mode(byte mode)
{
	union REGS regs;

	regs.h.ah = SET_MODE;
	regs.h.al = mode;
	int86(VIDEO_INT, &regs, &regs);
}

/**************************************************************************
 *  set_unchained_mode                                                    *
 *    resets VGA mode 0x13 to unchained mode to access all 256K of memory *
 **************************************************************************/

void set_unchained_mode(void)
{
	word i;
	dword *ptr=(dword *)VGA;            /* used for faster screen clearing */

	outp(SC_INDEX,  MEMORY_MODE);       /* turn off chain-4 mode */
	outp(SC_DATA,   0x06);

	outpw(SC_INDEX, ALL_PLANES);        /* set map mask to all 4 planes */

	for(i=0;i<0x4000;i++)               /* clear all 256K of memory */
		*ptr++ = 0;

	outp(CRTC_INDEX,UNDERLINE_LOCATION);/* turn off long mode */
	outp(CRTC_DATA, 0x00);

	outp(CRTC_INDEX,MODE_CONTROL);      /* turn on byte mode */
	outp(CRTC_DATA, 0xe3);
}

/**************************************************************************
 *  page_flip                                                             *
 *    switches the pages at the appropriate time and waits for the        *
 *    vertical retrace.                                                   *
 **************************************************************************/

void page_flip(word *page1,word *page2)
{
	word high_address,low_address;
	word temp;

	temp=*page1;
	*page1=*page2;
	*page2=temp;

	high_address = HIGH_ADDRESS | (*page1 & 0xff00);
	low_address  = LOW_ADDRESS  | (*page1 << 8);

#ifdef VERTICAL_RETRACE
	while ((inp(INPUT_STATUS_1) & DISPLAY_ENABLE));
#endif
	outpw(CRTC_INDEX, high_address);
	outpw(CRTC_INDEX, low_address);
#ifdef VERTICAL_RETRACE
	while (!(inp(INPUT_STATUS_1) & VRETRACE));
#endif
}
/**************************************************************************
 *  show_buffer                                                           *
 *    displays a memory buffer on the screen                              *
 **************************************************************************/

void show_buffer(byte *buffer)
{
#ifdef VERTICAL_RETRACE
	while ((inp(INPUT_STATUS_1) & VRETRACE));
	while (!(inp(INPUT_STATUS_1) & VRETRACE));
#endif
	memcpy(VGA,buffer,SCREEN_SIZE);
}
/**************************************************************************
 *  load_bmp                                                              *
 *    Loads a bitmap file into memory.                                    *
 **************************************************************************/

void load_bmp(char *file,BITMAP *b)
{
	FILE *fp;
	long index;
	word num_colors;
	int x;

	/* open the file */
	if ((fp = fopen(file,"rb")) == NULL)
	{
		printf("Error opening file %s.\n",file);
		exit(1);
	}

	/* check to see if it is a valid bitmap file */
	if (fgetc(fp)!='B' || fgetc(fp)!='M')
	{
		fclose(fp);
		printf("%s is not a bitmap file.\n",file);
		exit(1);
	}

	/* read in the width and height of the image, and the
	   number of colors used; ignore the rest */
	fskip(fp,16);
	fread(&b->width, sizeof(word), 1, fp);
	fskip(fp,2);
	fread(&b->height,sizeof(word), 1, fp);
	fskip(fp,22);
	fread(&num_colors,sizeof(word), 1, fp);
	fskip(fp,6);

	/* assume we are working with an 8-bit file */
	if (num_colors==0) num_colors=256;

	/* try to allocate memory */
	if ((b->data = (byte *) malloc((word)(b->width*b->height))) == NULL)
	{
		fclose(fp);
		printf("Error allocating memory for file %s.\n",file);
		exit(1);
	}

	/* read the palette information */
	for(index=0;index<num_colors;index++)
	{
		b->palette[(int)(index*3+2)] = fgetc(fp) >> 2;
		b->palette[(int)(index*3+1)] = fgetc(fp) >> 2;
		b->palette[(int)(index*3+0)] = fgetc(fp) >> 2;
		x=fgetc(fp);
	}

	/* read the bitmap */
	for(index = (b->height-1)*b->width; index >= 0;index-=b->width)
		for(x = 0; x < b->width; x++)
			b->data[(int)(index+x)]=(byte)fgetc(fp);

	fclose(fp);
}

/**************************************************************************
 *  set_palette                                                           *
 *    Sets all 256 colors of the palette.                                 *
 **************************************************************************/

void set_palette(byte *palette)
{
	int i;

	outp(PALETTE_INDEX,0);              /* tell the VGA that palette data
										   is coming. */
	for(i=0;i<256*3;i++)
		outp(PALETTE_DATA,palette[i]);    /* write the data */
}

/**************************************************************************
 *  plot_pixel                                                            *
 *    Plots a pixel in unchained mode                                     *
 **************************************************************************/

void plot_pixel(int x,int y,byte color)
{
	outp(SC_INDEX, MAP_MASK);          /* select plane */
	outp(SC_DATA,  1 << (x&3) );

	VGA[(y<<6)+(y<<4)+(x>>2)]=color;
}

/**************************************************************************
 *  Main                                                                  *
 **************************************************************************/

void main(int argc, char *argv[])
{
	word bitmap_offset,screen_offset;   //Offset from beginning of double_buffer?
	word visual_page = 0;				//The page currently shown
	word active_page = SCREEN_SIZE/4;	//The page being prepped. It's size/4 because of the four planes
	word start;
	float t1,t2;
	int i,repeat,plane,num_objects=0;
	word x,y;
	byte *double_buffer;
	BITMAP bmp;
	OBJECT *object;

	/* get command-line options */
	if (argc>0) num_objects=atoi(argv[1]);
	if (num_objects<=0) num_objects=8;

	/* allocate memory for double buffer and background image */
	if ((double_buffer = (byte *) malloc(SCREEN_SIZE)) == NULL)
	{
		printf("Not enough memory for double buffer.\n");
		exit(1);
	}
	/* allocate memory for objects */
	if ((object = (OBJECT *) malloc(sizeof(OBJECT)*num_objects)) == NULL)
	{
		printf("Not enough memory for objects.\n");
		free(double_buffer);
		exit(1);
	}

	/* load the images */
	load_bmp("balls.bmp",&bmp);

	/* set the object positions */
	srand(*my_clock);
	for(i=0;i<num_objects;i++)
	{
		object[i].width   = BITMAP_WIDTH;
		object[i].height  = BITMAP_HEIGHT;
		object[i].x       = rand() % (SCREEN_WIDTH - BITMAP_WIDTH );
		object[i].y       = rand() % (SCREEN_HEIGHT- BITMAP_HEIGHT);
		object[i].dx      = (rand()%5) - 2;
		object[i].dy      = (rand()%5) - 2;
	}

	set_mode(VGA_256_COLOR_MODE);       /* set the video mode. */
	set_palette(bmp.palette);

	start=*my_clock;                    /* record the starting time. */
	for(repeat=0;repeat<TOTAL_FRAMES;repeat++)
	{
		if ((repeat%ANIMATION_FRAMES)==0) bitmap_offset=0;
		/* clear background */
		memset(double_buffer,0,SCREEN_SIZE);

		for(i=0;i<num_objects;i++)
		{
			screen_offset = (object[i].y<<8) + (object[i].y<<6) + object[i].x;
			/* draw the object. */
			for(y=0;y<BITMAP_HEIGHT*bmp.width;y+=bmp.width)
				for(x=0;x<BITMAP_WIDTH;x++)
					if (bmp.data[bitmap_offset+y+x]!=0)
						double_buffer[screen_offset+y+x]=bmp.data[bitmap_offset+y+x];
			/* check to see if the object is within boundries */
			if (object[i].x + object[i].dx < 0 ||
					object[i].x + object[i].dx > SCREEN_WIDTH-object[i].width-1)
				object[i].dx=-object[i].dx;
			if (object[i].y + object[i].dy < 0 ||
					object[i].y + object[i].dy > SCREEN_HEIGHT-object[i].height-1)
				object[i].dy=-object[i].dy;
			/* move the object */
			object[i].x+=object[i].dx;
			object[i].y+=object[i].dy;
		}

		/* point to the next image in the animation */
		bitmap_offset+=BITMAP_WIDTH;
		if ((bitmap_offset%bmp.width)==0)
			bitmap_offset+=bmp.width*(BITMAP_HEIGHT-1);

		/* show the buffer */
		show_buffer(double_buffer);
	}
	t1=(*my_clock-start)/18.2;          /* calculate how long it took. */

	free(double_buffer);                /* free up memory used */

	/************************************************************************/

	set_unchained_mode();               /* set unchained mode */

	start=*my_clock;                    /* record the starting time. */
	for(repeat=0;repeat<TOTAL_FRAMES;repeat++)
	{
		if ((repeat%ANIMATION_FRAMES)==0) bitmap_offset=0;
		/* clear background */
		outpw(SC_INDEX,ALL_PLANES);
		memset(&VGA[active_page],0,SCREEN_SIZE/4);

		outp(SC_INDEX, MAP_MASK);          /* select plane */
		for(i=0;i<num_objects;i++)
		{
			screen_offset = (object[i].y<<6) + (object[i].y<<4) + (object[i].x>>2);
			/* draw the object. */
			for(plane=0;plane<4;plane++)
			{
				/* select plane */
				outp(SC_DATA,  1 << ((plane+object[i].x)&3) );
				for(y=0;y<BITMAP_HEIGHT*bmp.width;y+=bmp.width)
					for(x=plane;x<BITMAP_WIDTH;x+=4)
						if (bmp.data[bitmap_offset+y+x]!=0)
							VGA[active_page+screen_offset+(y>>2)+((x+(object[i].x&3)) >> 2)]=
								bmp.data[bitmap_offset+y+x];
			}
			/* check to see if the object is within boundries */
			if (object[i].x + object[i].dx < 0 ||
					object[i].x + object[i].dx > SCREEN_WIDTH-object[i].width-1)
				object[i].dx=-object[i].dx;
			if (object[i].y + object[i].dy < 0 ||
					object[i].y + object[i].dy > SCREEN_HEIGHT-object[i].height-1)
				object[i].dy=-object[i].dy;
			/* move the object */
			object[i].x+=object[i].dx;
			object[i].y+=object[i].dy;
		}

		/* point to the next image in the animation */
		bitmap_offset+=BITMAP_WIDTH;
		if ((bitmap_offset%bmp.width)==0)
			bitmap_offset+=bmp.width*(BITMAP_HEIGHT-1);

		/* flip the pages */
		page_flip(&visual_page,&active_page);
	}
	t2=(*my_clock-start)/18.2;          /* calculate how long it took. */

	free(bmp.data);
	free(object);

	set_mode(TEXT_MODE);                /* set the video mode back to
										   text mode. */
	/* output the results... */

	printf("Results with %i objects",num_objects);
#ifdef VERTICAL_RETRACE
	printf(":\n");
#else
	printf(" (vertical retrace *ignored*):\n");
#endif
	printf("  Mode 0x13 with double buffering:\n");
	printf("    %f seconds,\n",t1);
	printf("    %f frames per second.\n",(float)TOTAL_FRAMES/t1);
	printf("  Unchained mode with page flipping:\n");
	printf("    %f seconds,\n",t2);
	printf("    %f frames per second.\n",(float)TOTAL_FRAMES/t2);
	if (t2 != 0) 
		printf("  Unchained mode with page flipping was %f times faster.\n",t1/t2);

	return;
}
