#include "car_calc_ui.h"

int main(int argc, char** argv)
{
	Fl_Window* w = make_window();
	wake_grp_calculate();
	hide_all_groups();
	grp_calculate->show();
	w->show(argc, argv);
	return Fl::run();
} 
