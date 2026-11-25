#ifndef UI_V2_SCALE_H_INCLUDED
#define UI_V2_SCALE_H_INCLUDED

#include <FL/Fl.H>
#include <FL/Fl_Window.H>

// Implementation lives in car_calc_ui_v2.fl's decl block so FLUID regeneration
// preserves it.
//
// Resize-aware layout scaling. FLTK's proportional child stretching is
// disabled; widget boxes and fonts follow the window size while positive gaps
// between widgets keep their original pixel size. CARCALC_UI_SCALE (e.g. 1.5)
// overrides the derived factor. Must be called after make_window() and before
// the window is shown.
void ui_v2_scale_window(Fl_Window *window);

// Rebuild label rows after a language change updates .trs font sizes.
void ui_v2_relayout();

// Current factor, for code that sets font sizes later (translation applies
// .trs font sizes after scaling, so it must scale those sizes too).
double ui_v2_scale_factor();

// Scales an explicit font size using the current factor. Returns 0 when the
// input size is unset/unspecified.
int ui_v2_scaled_size(int size);

#endif // UI_V2_SCALE_H_INCLUDED
