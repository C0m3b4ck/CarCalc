#include "car_calc_ui.h"

int main(int argc, char** argv)
{
	Fl_Window* w = make_window(); // call make_window()
	w->show(argc, argv); // show window
	return Fl::run(); // return function return
} 
