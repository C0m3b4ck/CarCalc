#include "car_calc_ui_v2.h"
#include "ui_v2_scale.h"

#include "../language.h"
#include "../sql_layer.h"

static void configure_utf8_fonts()
{
	// FLTK 1.3 uses platform fonts for the built-in font slots. Enumerating
	// installed fonts first lets us replace those slots with faces that include
	// the French accents and non-breaking spaces stored in the DB.
	Fl::set_fonts(0);

#ifdef _WIN32
	const char *sans = "Segoe UI";
	const char *sans_bold = "Segoe UI Bold";
	const char *sans_italic = "Segoe UI Italic";
	const char *sans_bold_italic = "Segoe UI Bold Italic";
	const char *mono = "Consolas";
	const char *mono_bold = "Consolas Bold";
	const char *mono_italic = "Consolas Italic";
	const char *mono_bold_italic = "Consolas Bold Italic";
	const char *serif = "Times New Roman";
	const char *serif_bold = "Times New Roman Bold";
	const char *serif_italic = "Times New Roman Italic";
	const char *serif_bold_italic = "Times New Roman Bold Italic";
#else
	const char *sans = "DejaVu Sans";
	const char *sans_bold = "DejaVu Sans bold";
	const char *sans_italic = "DejaVu Sans italic";
	const char *sans_bold_italic = "DejaVu Sans bold italic";
	const char *mono = "DejaVu Sans Mono";
	const char *mono_bold = "DejaVu Sans Mono bold";
	const char *mono_italic = "DejaVu Sans Mono italic";
	const char *mono_bold_italic = "DejaVu Sans Mono bold italic";
	const char *serif = "DejaVu Serif";
	const char *serif_bold = "DejaVu Serif bold";
	const char *serif_italic = "DejaVu Serif italic";
	const char *serif_bold_italic = "DejaVu Serif bold italic";
#endif

	Fl::set_font(FL_HELVETICA, sans);
	Fl::set_font(FL_HELVETICA_BOLD, sans_bold);
	Fl::set_font(FL_HELVETICA_ITALIC, sans_italic);
	Fl::set_font(FL_HELVETICA_BOLD_ITALIC, sans_bold_italic);
	Fl::set_font(FL_COURIER, mono);
	Fl::set_font(FL_COURIER_BOLD, mono_bold);
	Fl::set_font(FL_COURIER_ITALIC, mono_italic);
	Fl::set_font(FL_COURIER_BOLD_ITALIC, mono_bold_italic);
	Fl::set_font(FL_TIMES, serif);
	Fl::set_font(FL_TIMES_BOLD, serif_bold);
	Fl::set_font(FL_TIMES_ITALIC, serif_italic);
	Fl::set_font(FL_TIMES_BOLD_ITALIC, serif_bold_italic);
}

int main(int argc, char **argv)
{
	configure_utf8_fonts();

	load_languages();
	set_database_path(database_path_for_current_language());

	Fl_Window *w = make_window();
	// One factor scales the whole UI: widgets, text and menu items.
	ui_v2_scale_window(w);
	wake_grp_calculate();
	hide_all_groups();
	grp_calculate->show();
	w->show(argc, argv);
	return Fl::run();
}
