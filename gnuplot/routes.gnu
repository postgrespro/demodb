set terminal svg size 1800,900
unset key

#set border 0

set lmargin 0
set rmargin 0
set tmargin 0
set bmargin 0

set xrange [-180:180]
set yrange [-90:90]

unset xtics
unset ytics

#set xtics geographic
#set ytics geographic
#set format x "%D°"
#set format y "%D°"
#
#set x2range [-180:180]
#set y2range [-90:90]
#set x2tics geographic
#set y2tics geographic
#set format x2 "%D°"
#set format y2 "%D°"

set multiplot

# Made with Natural Earth. Free vector and raster map data @ naturalearthdata.com.
# https://gnuplotting.org/plotting-raster-data-from-natural-earth/index.html

set datafile separator ','
set size ratio -1
plot 'world_color.txt' w rgbimage

# Plots of airports and routes on top on Earth map

set datafile separator whitespace
plot 'routes1_gc.dat' smooth csplines linewidth 1 lc rgb "#333333"
plot 'routes2_gc.dat' smooth csplines linewidth 2 lc rgb "#333333"
plot 'routes3_gc.dat' smooth csplines linewidth 3 lc rgb "#333333"
plot 'all_airports.dat' using 1:2:(0.1) with circles fs solid lc rgb "#000000"
plot 'airports.dat' using 1:2:(0.8) with circles fs solid lc rgb "#ff6600"
#plot 'airports.dat' using 1:2:(0.8) with circles fs solid lc rgb "#ff9900"

