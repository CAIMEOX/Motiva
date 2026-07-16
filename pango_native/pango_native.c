#ifndef MOTIVA_PANGO_VERSION_OK
#error "Motiva pango_native requires pangocairo 1.56 or newer"
#endif

#include <cairo.h>
#include <limits.h>
#include <math.h>
#include <moonbit.h>
#include <pango/pangocairo.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

enum {
  MOTIVA_PANGO_OK = 0,
  MOTIVA_PANGO_INVALID_ARGUMENT = 1,
  MOTIVA_PANGO_INVALID_MARKUP = 2,
  MOTIVA_PANGO_CAIRO_ERROR = 3,
  MOTIVA_PANGO_LAYOUT_ERROR = 4,
  MOTIVA_PANGO_FONT_ERROR = 5,
  MOTIVA_PANGO_UNSUPPORTED = 6,
  MOTIVA_PANGO_NOT_REGISTERED = 7,
};

typedef struct {
  PangoFontMap *font_map;
  GPtrArray *font_files;
  GMutex lock;
} MotivaPangoEngine;

typedef struct {
  char *source;
  int32_t source_length;
  gboolean markup;
  char *font_family;
  double font_size;
  PangoStyle slant;
  PangoWeight weight;
  PangoStretch stretch;
  double red;
  double green;
  double blue;
  double alpha;
  char *language;
  PangoAttrList *attributes;
  gboolean has_width;
  double width;
  int32_t height_mode;
  double height;
  PangoWrapMode wrap;
  PangoEllipsizeMode ellipsize;
  PangoAlignment alignment;
  gboolean justify;
  gboolean justify_last_line;
  double indent;
  double spacing;
  gboolean has_line_spacing;
  double line_spacing;
  gboolean auto_dir;
  int32_t direction;
  gboolean single_paragraph;
  double dpi;
} MotivaPangoJob;

typedef struct {
  int32_t source_start;
  int32_t source_end;
  int32_t glyph_start;
  int32_t glyph_end;
  int32_t line_index;
  int32_t bidi_level;
  double x;
  double y;
  double width;
  double height;
} MotivaPangoCluster;

typedef struct {
  int32_t source_start;
  int32_t source_end;
  double ink_x;
  double ink_y;
  double ink_width;
  double ink_height;
  double logical_x;
  double logical_y;
  double logical_width;
  double logical_height;
  double baseline;
} MotivaPangoLine;

typedef struct {
  int32_t status;
  char *message;
  char *svg;
  int32_t svg_length;
  char *text;
  int32_t text_length;
  double ink_x;
  double ink_y;
  double ink_width;
  double ink_height;
  double logical_x;
  double logical_y;
  double logical_width;
  double logical_height;
  double baseline;
  int32_t unknown_glyphs;
  int32_t glyph_count;
  GArray *clusters;
  GArray *lines;
} MotivaPangoRender;

typedef struct {
  int32_t code;
  char *message;
} MotivaPangoStatus;

typedef struct {
  char **names;
  int32_t length;
} MotivaPangoFontList;

typedef struct {
  int32_t source_start;
  int32_t source_end;
  int32_t first_glyph;
  int32_t glyph_limit;
} MotivaGlyphClusterSlice;

typedef struct _MotivaPangoSvgRenderer {
  PangoRenderer parent_instance;
  MotivaPangoRender *render;
  cairo_t *cairo;
  GString *elements;
  double origin_x;
  double origin_y;
  PangoColor base_color;
  guint16 base_alpha;
  PangoColor colors[5];
  guint16 alphas[5];
  gboolean failed;
} MotivaPangoSvgRenderer;

typedef struct _MotivaPangoSvgRendererClass {
  PangoRendererClass parent_class;
} MotivaPangoSvgRendererClass;

G_DEFINE_TYPE(
  MotivaPangoSvgRenderer,
  motiva_pango_svg_renderer,
  PANGO_TYPE_RENDERER
)

static char *motiva_copy_bytes(moonbit_bytes_t bytes, int32_t *length) {
  int32_t len = Moonbit_array_length(bytes);
  char *copy = (char *)g_malloc((size_t)len + 1);
  if (len > 0) {
    memcpy(copy, bytes, (size_t)len);
  }
  copy[len] = '\0';
  if (length != NULL) {
    *length = len;
  }
  return copy;
}

static moonbit_bytes_t motiva_make_bytes(const char *data, size_t length) {
  if (length > INT32_MAX) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)length, 0);
  if (length > 0 && data != NULL) {
    memcpy(bytes, data, length);
  }
  return bytes;
}

static double motiva_clamp01(double value) {
  if (value < 0.0) {
    return 0.0;
  }
  if (value > 1.0) {
    return 1.0;
  }
  return value;
}

static guint16 motiva_color_channel(double value) {
  return (guint16)lround(motiva_clamp01(value) * 65535.0);
}

static void motiva_pango_engine_finalize(void *pointer) {
  MotivaPangoEngine *engine = (MotivaPangoEngine *)pointer;
  if (engine->font_map != NULL) {
    g_object_unref(engine->font_map);
  }
  if (engine->font_files != NULL) {
    g_ptr_array_free(engine->font_files, TRUE);
  }
  g_mutex_clear(&engine->lock);
}

static void motiva_pango_job_finalize(void *pointer) {
  MotivaPangoJob *job = (MotivaPangoJob *)pointer;
  g_free(job->source);
  g_free(job->font_family);
  g_free(job->language);
  if (job->attributes != NULL) {
    pango_attr_list_unref(job->attributes);
  }
}

static void motiva_pango_render_finalize(void *pointer) {
  MotivaPangoRender *render = (MotivaPangoRender *)pointer;
  g_free(render->message);
  g_free(render->svg);
  g_free(render->text);
  if (render->clusters != NULL) {
    g_array_free(render->clusters, TRUE);
  }
  if (render->lines != NULL) {
    g_array_free(render->lines, TRUE);
  }
}

static void motiva_pango_status_finalize(void *pointer) {
  MotivaPangoStatus *status = (MotivaPangoStatus *)pointer;
  g_free(status->message);
}

static void motiva_pango_font_list_finalize(void *pointer) {
  MotivaPangoFontList *fonts = (MotivaPangoFontList *)pointer;
  if (fonts->names != NULL) {
    for (int32_t index = 0; index < fonts->length; index += 1) {
      g_free(fonts->names[index]);
    }
    g_free(fonts->names);
  }
}

static MotivaPangoStatus *motiva_status_new(int32_t code, const char *message) {
  MotivaPangoStatus *status = (MotivaPangoStatus *)moonbit_make_external_object(
    motiva_pango_status_finalize,
    sizeof(MotivaPangoStatus)
  );
  status->code = code;
  status->message = g_strdup(message == NULL ? "" : message);
  return status;
}

static MotivaPangoRender *motiva_render_new(void) {
  MotivaPangoRender *render =
    (MotivaPangoRender *)moonbit_make_external_object(
      motiva_pango_render_finalize,
      sizeof(MotivaPangoRender)
    );
  memset(render, 0, sizeof(MotivaPangoRender));
  render->message = g_strdup("");
  render->svg = g_strdup("");
  render->text = g_strdup("");
  render->clusters = g_array_new(FALSE, FALSE, sizeof(MotivaPangoCluster));
  render->lines = g_array_new(FALSE, FALSE, sizeof(MotivaPangoLine));
  return render;
}

static void motiva_render_error(
  MotivaPangoRender *render,
  int32_t status,
  const char *message
) {
  render->status = status;
  g_free(render->message);
  render->message = g_strdup(message == NULL ? "" : message);
}

static PangoFontMap *motiva_font_map_new(void) {
  return pango_cairo_font_map_new();
}

MOONBIT_FFI_EXPORT
MotivaPangoEngine *motiva_pango_engine_new(void) {
  MotivaPangoEngine *engine =
    (MotivaPangoEngine *)moonbit_make_external_object(
      motiva_pango_engine_finalize,
      sizeof(MotivaPangoEngine)
  );
  engine->font_map = motiva_font_map_new();
  engine->font_files = g_ptr_array_new_with_free_func(g_free);
  g_mutex_init(&engine->lock);
  return engine;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t motiva_pango_version(void) {
  const char *version = pango_version_string();
  return motiva_make_bytes(version, strlen(version));
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t motiva_cairo_version(void) {
  const char *version = cairo_version_string();
  return motiva_make_bytes(version, strlen(version));
}

static gboolean motiva_engine_has_font(
  const MotivaPangoEngine *engine,
  const char *path,
  guint *index
) {
  for (guint current = 0; current < engine->font_files->len; current += 1) {
    const char *registered = (const char *)g_ptr_array_index(
      engine->font_files,
      current
    );
    if (g_strcmp0(path, registered) == 0) {
      if (index != NULL) {
        *index = current;
      }
      return TRUE;
    }
  }
  return FALSE;
}

static gboolean motiva_add_font_file(
  PangoFontMap *font_map,
  const char *path,
  GError **error
) {
#if PANGO_VERSION_CHECK(1, 56, 0)
  return pango_font_map_add_font_file(font_map, path, error);
#else
  g_set_error_literal(
    error,
    g_quark_from_static_string("motiva-pango"),
    MOTIVA_PANGO_UNSUPPORTED,
    "Pango 1.56 or newer is required for runtime font registration"
  );
  return FALSE;
#endif
}

MOONBIT_FFI_EXPORT
MotivaPangoStatus *motiva_pango_engine_register_font(
  MotivaPangoEngine *engine,
  moonbit_bytes_t path_bytes
) {
  g_mutex_lock(&engine->lock);
  char *path = motiva_copy_bytes(path_bytes, NULL);
  if (path[0] == '\0') {
    g_free(path);
    MotivaPangoStatus *status = motiva_status_new(
      MOTIVA_PANGO_INVALID_ARGUMENT,
      "empty font path"
    );
    g_mutex_unlock(&engine->lock);
    return status;
  }
  if (motiva_engine_has_font(engine, path, NULL)) {
    g_free(path);
    MotivaPangoStatus *status = motiva_status_new(MOTIVA_PANGO_OK, "");
    g_mutex_unlock(&engine->lock);
    return status;
  }
  GError *error = NULL;
  if (!motiva_add_font_file(engine->font_map, path, &error)) {
    MotivaPangoStatus *status = motiva_status_new(
      MOTIVA_PANGO_FONT_ERROR,
      error == NULL ? "failed to register font" : error->message
    );
    g_clear_error(&error);
    g_free(path);
    g_mutex_unlock(&engine->lock);
    return status;
  }
  g_ptr_array_add(engine->font_files, path);
  pango_font_map_changed(engine->font_map);
  MotivaPangoStatus *status = motiva_status_new(MOTIVA_PANGO_OK, "");
  g_mutex_unlock(&engine->lock);
  return status;
}

MOONBIT_FFI_EXPORT
MotivaPangoStatus *motiva_pango_engine_unregister_font(
  MotivaPangoEngine *engine,
  moonbit_bytes_t path_bytes
) {
  g_mutex_lock(&engine->lock);
  char *path = motiva_copy_bytes(path_bytes, NULL);
  guint removed_index = 0;
  if (!motiva_engine_has_font(engine, path, &removed_index)) {
    MotivaPangoStatus *status = motiva_status_new(
      MOTIVA_PANGO_NOT_REGISTERED,
      "font is not registered with this text engine"
    );
    g_free(path);
    g_mutex_unlock(&engine->lock);
    return status;
  }
  PangoFontMap *replacement = motiva_font_map_new();
  GError *error = NULL;
  for (guint index = 0; index < engine->font_files->len; index += 1) {
    if (index == removed_index) {
      continue;
    }
    const char *registered = (const char *)g_ptr_array_index(
      engine->font_files,
      index
    );
    if (!motiva_add_font_file(replacement, registered, &error)) {
      MotivaPangoStatus *status = motiva_status_new(
        MOTIVA_PANGO_FONT_ERROR,
        error == NULL ? "failed to rebuild font map" : error->message
      );
      g_clear_error(&error);
      g_object_unref(replacement);
      g_free(path);
      g_mutex_unlock(&engine->lock);
      return status;
    }
  }
  g_object_unref(engine->font_map);
  engine->font_map = replacement;
  g_ptr_array_remove_index(engine->font_files, removed_index);
  g_free(path);
  MotivaPangoStatus *status = motiva_status_new(MOTIVA_PANGO_OK, "");
  g_mutex_unlock(&engine->lock);
  return status;
}

static int motiva_compare_font_names(const void *left, const void *right) {
  const char *const *left_name = (const char *const *)left;
  const char *const *right_name = (const char *const *)right;
  return g_utf8_collate(*left_name, *right_name);
}

MOONBIT_FFI_EXPORT
MotivaPangoFontList *motiva_pango_engine_list_fonts(
  MotivaPangoEngine *engine
) {
  g_mutex_lock(&engine->lock);
  PangoFontFamily **families = NULL;
  int count = 0;
  pango_font_map_list_families(engine->font_map, &families, &count);
  MotivaPangoFontList *fonts =
    (MotivaPangoFontList *)moonbit_make_external_object(
      motiva_pango_font_list_finalize,
      sizeof(MotivaPangoFontList)
    );
  fonts->length = count;
  fonts->names = count == 0
    ? NULL
    : (char **)g_malloc(sizeof(char *) * (size_t)count);
  for (int index = 0; index < count; index += 1) {
    fonts->names[index] = g_strdup(pango_font_family_get_name(families[index]));
  }
  g_free(families);
  if (count > 1) {
    qsort(
      fonts->names,
      (size_t)count,
      sizeof(char *),
      motiva_compare_font_names
    );
  }
  g_mutex_unlock(&engine->lock);
  return fonts;
}

MOONBIT_FFI_EXPORT
int32_t motiva_pango_status_code(const MotivaPangoStatus *status) {
  return status->code;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t motiva_pango_status_message(const MotivaPangoStatus *status) {
  return motiva_make_bytes(status->message, strlen(status->message));
}

MOONBIT_FFI_EXPORT
int32_t motiva_pango_font_list_length(const MotivaPangoFontList *fonts) {
  return fonts->length;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t motiva_pango_font_list_get(
  const MotivaPangoFontList *fonts,
  int32_t index
) {
  if (index < 0 || index >= fonts->length) {
    return motiva_make_bytes("", 0);
  }
  return motiva_make_bytes(fonts->names[index], strlen(fonts->names[index]));
}

static void motiva_add_attribute(
  MotivaPangoJob *job,
  PangoAttribute *attribute,
  int32_t start,
  int32_t end
) {
  attribute->start_index = (guint)start;
  attribute->end_index = (guint)end;
  pango_attr_list_change(job->attributes, attribute);
}

static void motiva_add_attribute_to_end(
  MotivaPangoJob *job,
  PangoAttribute *attribute
) {
  attribute->start_index = 0;
  attribute->end_index = PANGO_ATTR_INDEX_TO_TEXT_END;
  pango_attr_list_change(job->attributes, attribute);
}

MOONBIT_FFI_EXPORT
MotivaPangoJob *motiva_pango_job_new(
  moonbit_bytes_t text,
  int32_t markup
) {
  MotivaPangoJob *job = (MotivaPangoJob *)moonbit_make_external_object(
    motiva_pango_job_finalize,
    sizeof(MotivaPangoJob)
  );
  memset(job, 0, sizeof(MotivaPangoJob));
  job->source = motiva_copy_bytes(text, &job->source_length);
  job->markup = markup != 0;
  job->font_family = g_strdup("");
  job->font_size = 10.0;
  job->slant = PANGO_STYLE_NORMAL;
  job->weight = PANGO_WEIGHT_NORMAL;
  job->stretch = PANGO_STRETCH_NORMAL;
  job->red = 1.0;
  job->green = 1.0;
  job->blue = 1.0;
  job->alpha = 1.0;
  job->language = g_strdup("");
  job->attributes = pango_attr_list_new();
  job->wrap = PANGO_WRAP_WORD;
  job->ellipsize = PANGO_ELLIPSIZE_NONE;
  job->alignment = PANGO_ALIGN_LEFT;
  job->auto_dir = TRUE;
  job->direction = -1;
  job->dpi = 96.0;
  return job;
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_set_font(
  MotivaPangoJob *job,
  moonbit_bytes_t font_family,
  double font_size,
  int32_t slant,
  int32_t weight,
  int32_t stretch
) {
  g_free(job->font_family);
  job->font_family = motiva_copy_bytes(font_family, NULL);
  job->font_size = font_size;
  job->slant = (PangoStyle)slant;
  job->weight = (PangoWeight)weight;
  job->stretch = (PangoStretch)stretch;
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_set_paint(
  MotivaPangoJob *job,
  double red,
  double green,
  double blue,
  double alpha
) {
  job->red = motiva_clamp01(red);
  job->green = motiva_clamp01(green);
  job->blue = motiva_clamp01(blue);
  job->alpha = motiva_clamp01(alpha);
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_set_base_language(
  MotivaPangoJob *job,
  moonbit_bytes_t language
) {
  g_free(job->language);
  job->language = motiva_copy_bytes(language, NULL);
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_set_base_features(
  MotivaPangoJob *job,
  moonbit_bytes_t font_features
) {
  int32_t features_length = 0;
  char *features = motiva_copy_bytes(font_features, &features_length);
  if (features_length > 0) {
    motiva_add_attribute_to_end(job, pango_attr_font_features_new(features));
  }
  g_free(features);
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_set_box(
  MotivaPangoJob *job,
  int32_t has_width,
  double width,
  int32_t height_mode,
  double height,
  double dpi
) {
  job->has_width = has_width != 0;
  job->width = width;
  job->height_mode = height_mode;
  job->height = height;
  job->dpi = dpi;
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_set_flow(
  MotivaPangoJob *job,
  int32_t wrap,
  int32_t ellipsize,
  int32_t alignment,
  int32_t auto_dir,
  int32_t direction,
  int32_t single_paragraph
) {
  job->wrap = (PangoWrapMode)wrap;
  job->ellipsize = (PangoEllipsizeMode)ellipsize;
  job->alignment = (PangoAlignment)alignment;
  job->auto_dir = auto_dir != 0;
  job->direction = direction;
  job->single_paragraph = single_paragraph != 0;
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_set_paragraph(
  MotivaPangoJob *job,
  int32_t justify,
  int32_t justify_last_line,
  double indent,
  double spacing,
  int32_t has_line_spacing,
  double line_spacing
) {
  job->justify = justify != 0;
  job->justify_last_line = justify_last_line != 0;
  job->indent = indent;
  job->spacing = spacing;
  job->has_line_spacing = has_line_spacing != 0;
  job->line_spacing = line_spacing;
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_family(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  moonbit_bytes_t family_bytes
) {
  char *family = motiva_copy_bytes(family_bytes, NULL);
  motiva_add_attribute(job, pango_attr_family_new(family), start, end);
  g_free(family);
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_size(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  double size
) {
  motiva_add_attribute(
    job,
    pango_attr_size_new(pango_units_from_double(size)),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_slant(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  int32_t slant
) {
  motiva_add_attribute(
    job,
    pango_attr_style_new((PangoStyle)slant),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_weight(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  int32_t weight
) {
  motiva_add_attribute(
    job,
    pango_attr_weight_new((PangoWeight)weight),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_stretch(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  int32_t stretch
) {
  motiva_add_attribute(
    job,
    pango_attr_stretch_new((PangoStretch)stretch),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_foreground(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  double red,
  double green,
  double blue,
  double alpha
) {
  motiva_add_attribute(
    job,
    pango_attr_foreground_new(
      motiva_color_channel(red),
      motiva_color_channel(green),
      motiva_color_channel(blue)
    ),
    start,
    end
  );
  motiva_add_attribute(
    job,
    pango_attr_foreground_alpha_new(motiva_color_channel(alpha)),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_background(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  double red,
  double green,
  double blue,
  double alpha
) {
  motiva_add_attribute(
    job,
    pango_attr_background_new(
      motiva_color_channel(red),
      motiva_color_channel(green),
      motiva_color_channel(blue)
    ),
    start,
    end
  );
  motiva_add_attribute(
    job,
    pango_attr_background_alpha_new(motiva_color_channel(alpha)),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_underline(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  int32_t underline
) {
  motiva_add_attribute(
    job,
    pango_attr_underline_new((PangoUnderline)underline),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_underline_color(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  double red,
  double green,
  double blue
) {
  motiva_add_attribute(
    job,
    pango_attr_underline_color_new(
      motiva_color_channel(red),
      motiva_color_channel(green),
      motiva_color_channel(blue)
    ),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_overline(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  int32_t enabled
) {
#if PANGO_VERSION_CHECK(1, 46, 0)
  motiva_add_attribute(
    job,
    pango_attr_overline_new(enabled ? PANGO_OVERLINE_SINGLE : PANGO_OVERLINE_NONE),
    start,
    end
  );
#else
  (void)job;
  (void)start;
  (void)end;
  (void)enabled;
#endif
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_overline_color(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  double red,
  double green,
  double blue
) {
#if PANGO_VERSION_CHECK(1, 46, 0)
  motiva_add_attribute(
    job,
    pango_attr_overline_color_new(
      motiva_color_channel(red),
      motiva_color_channel(green),
      motiva_color_channel(blue)
    ),
    start,
    end
  );
#else
  (void)job;
  (void)start;
  (void)end;
  (void)red;
  (void)green;
  (void)blue;
#endif
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_strikethrough(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  int32_t enabled
) {
  motiva_add_attribute(
    job,
    pango_attr_strikethrough_new(enabled != 0),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_strikethrough_color(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  double red,
  double green,
  double blue
) {
  motiva_add_attribute(
    job,
    pango_attr_strikethrough_color_new(
      motiva_color_channel(red),
      motiva_color_channel(green),
      motiva_color_channel(blue)
    ),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_rise(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  double rise
) {
  motiva_add_attribute(
    job,
    pango_attr_rise_new(pango_units_from_double(rise)),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_letter_spacing(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  double spacing
) {
  motiva_add_attribute(
    job,
    pango_attr_letter_spacing_new(pango_units_from_double(spacing)),
    start,
    end
  );
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_font_features(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  moonbit_bytes_t features_bytes
) {
  char *features = motiva_copy_bytes(features_bytes, NULL);
  motiva_add_attribute(
    job,
    pango_attr_font_features_new(features),
    start,
    end
  );
  g_free(features);
}

MOONBIT_FFI_EXPORT
void motiva_pango_job_add_language(
  MotivaPangoJob *job,
  int32_t start,
  int32_t end,
  moonbit_bytes_t language_bytes
) {
  char *language = motiva_copy_bytes(language_bytes, NULL);
  motiva_add_attribute(
    job,
    pango_attr_language_new(pango_language_from_string(language)),
    start,
    end
  );
  g_free(language);
}

static void motiva_overlay_attributes(
  PangoAttrList *target,
  PangoAttrList *overlay
) {
  PangoAttrIterator *iterator = pango_attr_list_get_iterator(overlay);
  gboolean more = TRUE;
  while (more) {
    GSList *attributes = pango_attr_iterator_get_attrs(iterator);
    for (GSList *entry = attributes; entry != NULL; entry = entry->next) {
      pango_attr_list_change(target, (PangoAttribute *)entry->data);
    }
    g_slist_free(attributes);
    more = pango_attr_iterator_next(iterator);
  }
  pango_attr_iterator_destroy(iterator);
}

static gboolean motiva_configure_layout(
  const MotivaPangoEngine *engine,
  const MotivaPangoJob *job,
  cairo_t *cairo,
  PangoLayout **layout_out,
  char **text_out,
  MotivaPangoRender *render
) {
  PangoContext *context = pango_font_map_create_context(engine->font_map);
  if (context == NULL) {
    motiva_render_error(render, MOTIVA_PANGO_LAYOUT_ERROR, "failed to create Pango context");
    return FALSE;
  }
  pango_cairo_context_set_resolution(context, job->dpi);
  if (job->direction >= 0) {
    pango_context_set_base_dir(context, (PangoDirection)job->direction);
  } else {
    pango_context_set_base_dir(context, PANGO_DIRECTION_WEAK_LTR);
  }
  if (job->language[0] != '\0') {
    pango_context_set_language(context, pango_language_from_string(job->language));
  }
  pango_cairo_update_context(cairo, context);
  PangoLayout *layout = pango_layout_new(context);
  g_object_unref(context);
  if (layout == NULL) {
    motiva_render_error(render, MOTIVA_PANGO_LAYOUT_ERROR, "failed to create Pango layout");
    return FALSE;
  }

  PangoFontDescription *description = pango_font_description_new();
  if (job->font_family[0] != '\0') {
    pango_font_description_set_family(description, job->font_family);
  }
  pango_font_description_set_size(
    description,
    pango_units_from_double(job->font_size)
  );
  pango_font_description_set_style(description, job->slant);
  pango_font_description_set_weight(description, job->weight);
  pango_font_description_set_stretch(description, job->stretch);
  pango_layout_set_font_description(layout, description);
  pango_font_description_free(description);

  char *plain_text = NULL;
  PangoAttrList *attributes = NULL;
  if (job->markup) {
    GError *error = NULL;
    if (!pango_parse_markup(
          job->source,
          job->source_length,
          0,
          &attributes,
          &plain_text,
          NULL,
          &error
        )) {
      motiva_render_error(
        render,
        MOTIVA_PANGO_INVALID_MARKUP,
        error == NULL ? "invalid Pango markup" : error->message
      );
      g_clear_error(&error);
      g_object_unref(layout);
      return FALSE;
    }
    motiva_overlay_attributes(attributes, job->attributes);
  } else {
    plain_text = g_strndup(job->source, (gsize)job->source_length);
    attributes = pango_attr_list_copy(job->attributes);
  }
  pango_layout_set_text(layout, plain_text, -1);
  pango_layout_set_attributes(layout, attributes);
  pango_attr_list_unref(attributes);

  if (job->has_width) {
    pango_layout_set_width(layout, pango_units_from_double(job->width));
  }
  if (job->height_mode == 1) {
    pango_layout_set_height(layout, pango_units_from_double(job->height));
  } else if (job->height_mode == 2) {
    pango_layout_set_height(layout, 0 - (int32_t)job->height);
  }
  pango_layout_set_wrap(layout, job->wrap);
  pango_layout_set_ellipsize(layout, job->ellipsize);
  pango_layout_set_alignment(layout, job->alignment);
  pango_layout_set_justify(layout, job->justify);
#if PANGO_VERSION_CHECK(1, 50, 0)
  pango_layout_set_justify_last_line(layout, job->justify_last_line);
#endif
  pango_layout_set_indent(layout, pango_units_from_double(job->indent));
  pango_layout_set_spacing(layout, pango_units_from_double(job->spacing));
#if PANGO_VERSION_CHECK(1, 44, 0)
  if (job->has_line_spacing) {
    pango_layout_set_line_spacing(layout, (float)job->line_spacing);
  }
#endif
  pango_layout_set_auto_dir(layout, job->auto_dir);
  pango_layout_set_single_paragraph_mode(layout, job->single_paragraph);
  pango_cairo_update_layout(cairo, layout);
  *layout_out = layout;
  *text_out = plain_text;
  return TRUE;
}

static double motiva_pango_units(int value) {
  return pango_units_to_double(value);
}

static void motiva_collect_lines(
  PangoLayout *layout,
  MotivaPangoRender *render
) {
  PangoLayoutIter *iterator = pango_layout_get_iter(layout);
  if (iterator == NULL) {
    return;
  }
  gboolean more = TRUE;
  while (more) {
    PangoLayoutLine *line = pango_layout_iter_get_line_readonly(iterator);
    PangoRectangle ink;
    PangoRectangle logical;
    pango_layout_iter_get_line_extents(iterator, &ink, &logical);
    MotivaPangoLine record;
    record.source_start = line->start_index;
    record.source_end = line->start_index + line->length;
    record.ink_x = motiva_pango_units(ink.x);
    record.ink_y = motiva_pango_units(ink.y);
    record.ink_width = motiva_pango_units(ink.width);
    record.ink_height = motiva_pango_units(ink.height);
    record.logical_x = motiva_pango_units(logical.x);
    record.logical_y = motiva_pango_units(logical.y);
    record.logical_width = motiva_pango_units(logical.width);
    record.logical_height = motiva_pango_units(logical.height);
    record.baseline = motiva_pango_units(pango_layout_iter_get_baseline(iterator));
    g_array_append_val(render->lines, record);
    more = pango_layout_iter_next_line(iterator);
  }
  pango_layout_iter_free(iterator);
}

static void motiva_svg_append_number(GString *output, double value) {
  char buffer[G_ASCII_DTOSTR_BUF_SIZE];
  g_ascii_dtostr(buffer, sizeof(buffer), value);
  g_string_append(output, buffer);
}

static void motiva_svg_append_color(
  GString *output,
  const PangoColor *color,
  guint16 alpha
) {
  guint red = color == NULL ? 255 : color->red / 257;
  guint green = color == NULL ? 255 : color->green / 257;
  guint blue = color == NULL ? 255 : color->blue / 257;
  g_string_append_printf(
    output,
    " fill=\"#%02x%02x%02x\" fill-opacity=\"",
    red,
    green,
    blue
  );
  motiva_svg_append_number(output, (double)alpha / 65535.0);
  g_string_append_c(output, '"');
}

static gboolean motiva_svg_append_path(
  GString *output,
  const cairo_path_t *path,
  const PangoColor *color,
  guint16 alpha
) {
  GString *data = g_string_new(NULL);
  gboolean draws = FALSE;
  for (int index = 0; index < path->num_data;) {
    cairo_path_data_t *command = &path->data[index];
    switch (command->header.type) {
      case CAIRO_PATH_MOVE_TO:
        g_string_append(data, "M ");
        motiva_svg_append_number(data, path->data[index + 1].point.x);
        g_string_append_c(data, ' ');
        motiva_svg_append_number(data, path->data[index + 1].point.y);
        g_string_append_c(data, ' ');
        break;
      case CAIRO_PATH_LINE_TO:
        draws = TRUE;
        g_string_append(data, "L ");
        motiva_svg_append_number(data, path->data[index + 1].point.x);
        g_string_append_c(data, ' ');
        motiva_svg_append_number(data, path->data[index + 1].point.y);
        g_string_append_c(data, ' ');
        break;
      case CAIRO_PATH_CURVE_TO:
        draws = TRUE;
        g_string_append(data, "C ");
        for (int point = 1; point <= 3; point += 1) {
          motiva_svg_append_number(data, path->data[index + point].point.x);
          g_string_append_c(data, ' ');
          motiva_svg_append_number(data, path->data[index + point].point.y);
          g_string_append_c(data, ' ');
        }
        break;
      case CAIRO_PATH_CLOSE_PATH:
        draws = TRUE;
        g_string_append(data, "Z ");
        break;
    }
    index += command->header.length;
  }
  if (!draws) {
    g_string_free(data, TRUE);
    return FALSE;
  }
  g_string_append(output, "<path d=\"");
  g_string_append_len(output, data->str, (gssize)data->len);
  g_string_append_c(output, '"');
  motiva_svg_append_color(output, color, alpha);
  g_string_append(output, "/>\n");
  g_string_free(data, TRUE);
  return TRUE;
}

static void motiva_svg_append_rectangle(
  GString *output,
  double x,
  double y,
  double width,
  double height,
  const PangoColor *color,
  guint16 alpha
) {
  double left = width < 0.0 ? x + width : x;
  double top = height < 0.0 ? y + height : y;
  g_string_append(output, "<rect x=\"");
  motiva_svg_append_number(output, left);
  g_string_append(output, "\" y=\"");
  motiva_svg_append_number(output, top);
  g_string_append(output, "\" width=\"");
  motiva_svg_append_number(output, fabs(width));
  g_string_append(output, "\" height=\"");
  motiva_svg_append_number(output, fabs(height));
  g_string_append_c(output, '"');
  motiva_svg_append_color(output, color, alpha);
  g_string_append(output, "/>\n");
}

static gint motiva_compare_cluster_slices(
  gconstpointer left,
  gconstpointer right
) {
  const MotivaGlyphClusterSlice *left_slice = left;
  const MotivaGlyphClusterSlice *right_slice = right;
  return left_slice->first_glyph - right_slice->first_glyph;
}

static int32_t motiva_renderer_line_index(PangoRenderer *renderer) {
  PangoLayout *layout = pango_renderer_get_layout(renderer);
  PangoLayoutLine *current = pango_renderer_get_layout_line(renderer);
  if (layout == NULL || current == NULL) {
    return -1;
  }
  int32_t index = 0;
  for (
    GSList *entry = pango_layout_get_lines_readonly(layout);
    entry != NULL;
    entry = entry->next
  ) {
    if (entry->data == current) {
      return index;
    }
    index += 1;
  }
  return -1;
}

static void motiva_renderer_fail(
  MotivaPangoSvgRenderer *renderer,
  const char *message
) {
  if (!renderer->failed) {
    renderer->failed = TRUE;
    motiva_render_error(
      renderer->render,
      MOTIVA_PANGO_CAIRO_ERROR,
      message
    );
  }
}

static const PangoColor *motiva_renderer_color(
  MotivaPangoSvgRenderer *renderer,
  PangoRenderPart part
) {
  return &renderer->colors[part];
}

static guint16 motiva_renderer_alpha(
  MotivaPangoSvgRenderer *renderer,
  PangoRenderPart part
) {
  return renderer->alphas[part];
}

static void motiva_renderer_prepare_run(
  PangoRenderer *base,
  PangoLayoutRun *run
) {
  MotivaPangoSvgRenderer *renderer = (MotivaPangoSvgRenderer *)base;
  for (int part = 0; part < 5; part += 1) {
    renderer->colors[part] = renderer->base_color;
    renderer->alphas[part] = renderer->base_alpha;
  }
  for (
    GSList *entry = run->item->analysis.extra_attrs;
    entry != NULL;
    entry = entry->next
  ) {
    PangoAttribute *attribute = (PangoAttribute *)entry->data;
    if (attribute->klass->type == PANGO_ATTR_FOREGROUND) {
      PangoColor color = ((PangoAttrColor *)attribute)->color;
      renderer->colors[PANGO_RENDER_PART_FOREGROUND] = color;
      renderer->colors[PANGO_RENDER_PART_UNDERLINE] = color;
      renderer->colors[PANGO_RENDER_PART_STRIKETHROUGH] = color;
      renderer->colors[PANGO_RENDER_PART_OVERLINE] = color;
    } else if (attribute->klass->type == PANGO_ATTR_BACKGROUND) {
      renderer->colors[PANGO_RENDER_PART_BACKGROUND] =
        ((PangoAttrColor *)attribute)->color;
    } else if (attribute->klass->type == PANGO_ATTR_FOREGROUND_ALPHA) {
      guint16 alpha = (guint16)((PangoAttrInt *)attribute)->value;
      renderer->alphas[PANGO_RENDER_PART_FOREGROUND] = alpha;
      renderer->alphas[PANGO_RENDER_PART_UNDERLINE] = alpha;
      renderer->alphas[PANGO_RENDER_PART_STRIKETHROUGH] = alpha;
      renderer->alphas[PANGO_RENDER_PART_OVERLINE] = alpha;
    } else if (attribute->klass->type == PANGO_ATTR_BACKGROUND_ALPHA) {
      renderer->alphas[PANGO_RENDER_PART_BACKGROUND] =
        (guint16)((PangoAttrInt *)attribute)->value;
    }
  }
  for (
    GSList *entry = run->item->analysis.extra_attrs;
    entry != NULL;
    entry = entry->next
  ) {
    PangoAttribute *attribute = (PangoAttribute *)entry->data;
    if (attribute->klass->type == PANGO_ATTR_UNDERLINE_COLOR) {
      renderer->colors[PANGO_RENDER_PART_UNDERLINE] =
        ((PangoAttrColor *)attribute)->color;
    } else if (attribute->klass->type == PANGO_ATTR_STRIKETHROUGH_COLOR) {
      renderer->colors[PANGO_RENDER_PART_STRIKETHROUGH] =
        ((PangoAttrColor *)attribute)->color;
    } else if (attribute->klass->type == PANGO_ATTR_OVERLINE_COLOR) {
      renderer->colors[PANGO_RENDER_PART_OVERLINE] =
        ((PangoAttrColor *)attribute)->color;
    }
  }
}

static gboolean motiva_append_glyph_path(
  MotivaPangoSvgRenderer *renderer,
  GString *output,
  PangoFont *font,
  PangoGlyphInfo info,
  double x,
  double y,
  const PangoColor *color,
  guint16 alpha
) {
  int log_cluster = 0;
  PangoGlyphString glyph_string;
  memset(&glyph_string, 0, sizeof(PangoGlyphString));
  glyph_string.num_glyphs = 1;
  glyph_string.glyphs = &info;
  glyph_string.log_clusters = &log_cluster;
  cairo_new_path(renderer->cairo);
  cairo_move_to(
    renderer->cairo,
    x + renderer->origin_x,
    y + renderer->origin_y
  );
  pango_cairo_glyph_string_path(renderer->cairo, font, &glyph_string);
  cairo_path_t *path = cairo_copy_path(renderer->cairo);
  cairo_status_t status = path->status;
  gboolean appended = FALSE;
  if (status == CAIRO_STATUS_SUCCESS) {
    appended = motiva_svg_append_path(output, path, color, alpha);
  } else {
    motiva_renderer_fail(renderer, cairo_status_to_string(status));
  }
  cairo_path_destroy(path);
  return appended;
}

static void motiva_renderer_draw_glyph_item(
  PangoRenderer *base,
  const char *text,
  PangoGlyphItem *glyph_item,
  int x,
  int y
) {
  MotivaPangoSvgRenderer *renderer = (MotivaPangoSvgRenderer *)base;
  PangoGlyphString *glyphs = glyph_item->glyphs;
  PangoFont *font = glyph_item->item->analysis.font;
  int32_t line_index = motiva_renderer_line_index(base);
  if (renderer->failed || glyphs == NULL || font == NULL || line_index < 0) {
    motiva_renderer_fail(renderer, "invalid Pango glyph item");
    return;
  }

  GArray *slices = g_array_new(FALSE, FALSE, sizeof(MotivaGlyphClusterSlice));
  PangoGlyphItemIter iterator;
  gboolean has_cluster = pango_glyph_item_iter_init_start(
    &iterator,
    glyph_item,
    text
  );
  while (has_cluster) {
    MotivaGlyphClusterSlice slice;
    slice.source_start = iterator.start_index;
    slice.source_end = iterator.end_index;
    if (iterator.start_glyph <= iterator.end_glyph) {
      slice.first_glyph = iterator.start_glyph;
      slice.glyph_limit = iterator.end_glyph;
    } else {
      slice.first_glyph = iterator.end_glyph + 1;
      slice.glyph_limit = iterator.start_glyph + 1;
    }
    if (
      slice.first_glyph < 0 ||
      slice.glyph_limit < slice.first_glyph ||
      slice.glyph_limit > glyphs->num_glyphs
    ) {
      motiva_renderer_fail(renderer, "invalid Pango cluster glyph range");
      g_array_free(slices, TRUE);
      return;
    }
    g_array_append_val(slices, slice);
    has_cluster = pango_glyph_item_iter_next_cluster(&iterator);
  }
  g_array_sort(slices, motiva_compare_cluster_slices);

  int64_t *positions = g_new(int64_t, (size_t)glyphs->num_glyphs + 1);
  positions[0] = x;
  for (int32_t glyph = 0; glyph < glyphs->num_glyphs; glyph += 1) {
    positions[glyph + 1] =
      positions[glyph] + glyphs->glyphs[glyph].geometry.width;
  }
  PangoLayoutLine *line = pango_renderer_get_layout_line(base);
  PangoLayout *layout = pango_renderer_get_layout(base);
  const PangoColor *color = motiva_renderer_color(
    renderer,
    PANGO_RENDER_PART_FOREGROUND
  );
  guint16 alpha = motiva_renderer_alpha(
    renderer,
    PANGO_RENDER_PART_FOREGROUND
  );

  for (guint slice_index = 0; slice_index < slices->len; slice_index += 1) {
    MotivaGlyphClusterSlice slice = g_array_index(
      slices,
      MotivaGlyphClusterSlice,
      slice_index
    );
    GString *cluster_svg = g_string_new(NULL);
    MotivaPangoCluster record;
    record.source_start = slice.source_start;
    record.source_end = slice.source_end;
    record.glyph_start = renderer->render->glyph_count;
    for (
      int32_t glyph = slice.first_glyph;
      glyph < slice.glyph_limit;
      glyph += 1
    ) {
      PangoGlyphInfo info = glyphs->glyphs[glyph];
      if (info.glyph == PANGO_GLYPH_EMPTY) {
        continue;
      }
      renderer->render->glyph_count += 1;
      motiva_append_glyph_path(
        renderer,
        cluster_svg,
        font,
        info,
        (double)positions[glyph] / PANGO_SCALE,
        motiva_pango_units(y),
        color,
        alpha
      );
    }
    record.glyph_end = renderer->render->glyph_count;
    record.line_index = line_index;
    record.bidi_level = glyph_item->item->analysis.level;
    int x_start = 0;
    int x_end = 0;
    pango_layout_line_index_to_x(
      line,
      slice.source_start,
      FALSE,
      &x_start
    );
    pango_layout_line_index_to_x(
      line,
      slice.source_end,
      FALSE,
      &x_end
    );
    record.x = motiva_pango_units(MIN(x_start, x_end));
    PangoRectangle position;
    pango_layout_index_to_pos(layout, slice.source_start, &position);
    record.y = motiva_pango_units(position.y);
    record.width = motiva_pango_units(abs(x_end - x_start));
    record.height = motiva_pango_units(position.height);
    guint cluster_index = renderer->render->clusters->len;
    g_array_append_val(renderer->render->clusters, record);
    if (cluster_svg->len > 0) {
      g_string_append_printf(
        renderer->elements,
        "<g id=\"motiva-cluster-%u\">\n",
        cluster_index
      );
      g_string_append_len(
        renderer->elements,
        cluster_svg->str,
        (gssize)cluster_svg->len
      );
      g_string_append(renderer->elements, "</g>\n");
    }
    g_string_free(cluster_svg, TRUE);
  }
  g_free(positions);
  g_array_free(slices, TRUE);
}

static void motiva_renderer_draw_rectangle(
  PangoRenderer *base,
  PangoRenderPart part,
  int x,
  int y,
  int width,
  int height
) {
  MotivaPangoSvgRenderer *renderer = (MotivaPangoSvgRenderer *)base;
  motiva_svg_append_rectangle(
    renderer->elements,
    motiva_pango_units(x) + renderer->origin_x,
    motiva_pango_units(y) + renderer->origin_y,
    motiva_pango_units(width),
    motiva_pango_units(height),
    motiva_renderer_color(renderer, part),
    motiva_renderer_alpha(renderer, part)
  );
}

static void motiva_renderer_draw_error_underline(
  PangoRenderer *base,
  int x,
  int y,
  int width,
  int height
) {
  MotivaPangoSvgRenderer *renderer = (MotivaPangoSvgRenderer *)base;
  cairo_new_path(renderer->cairo);
  pango_cairo_error_underline_path(
    renderer->cairo,
    motiva_pango_units(x) + renderer->origin_x,
    motiva_pango_units(y) + renderer->origin_y,
    motiva_pango_units(width),
    motiva_pango_units(height)
  );
  cairo_path_t *path = cairo_copy_path(renderer->cairo);
  if (path->status == CAIRO_STATUS_SUCCESS) {
    motiva_svg_append_path(
      renderer->elements,
      path,
      motiva_renderer_color(renderer, PANGO_RENDER_PART_UNDERLINE),
      motiva_renderer_alpha(renderer, PANGO_RENDER_PART_UNDERLINE)
    );
  } else {
    motiva_renderer_fail(renderer, cairo_status_to_string(path->status));
  }
  cairo_path_destroy(path);
}

static void motiva_renderer_draw_trapezoid(
  PangoRenderer *base,
  PangoRenderPart part,
  double y1,
  double x11,
  double x21,
  double y2,
  double x12,
  double x22
) {
  MotivaPangoSvgRenderer *renderer = (MotivaPangoSvgRenderer *)base;
  GString *path_data = g_string_new(NULL);
  g_string_append(path_data, "M ");
  motiva_svg_append_number(path_data, x11 + renderer->origin_x);
  g_string_append_c(path_data, ' ');
  motiva_svg_append_number(path_data, y1 + renderer->origin_y);
  g_string_append(path_data, " L ");
  motiva_svg_append_number(path_data, x21 + renderer->origin_x);
  g_string_append_c(path_data, ' ');
  motiva_svg_append_number(path_data, y1 + renderer->origin_y);
  g_string_append(path_data, " L ");
  motiva_svg_append_number(path_data, x22 + renderer->origin_x);
  g_string_append_c(path_data, ' ');
  motiva_svg_append_number(path_data, y2 + renderer->origin_y);
  g_string_append(path_data, " L ");
  motiva_svg_append_number(path_data, x12 + renderer->origin_x);
  g_string_append_c(path_data, ' ');
  motiva_svg_append_number(path_data, y2 + renderer->origin_y);
  g_string_append(renderer->elements, "<path d=\"");
  g_string_append_len(
    renderer->elements,
    path_data->str,
    (gssize)path_data->len
  );
  g_string_append(renderer->elements, " Z\"");
  motiva_svg_append_color(
    renderer->elements,
    motiva_renderer_color(renderer, part),
    motiva_renderer_alpha(renderer, part)
  );
  g_string_append(renderer->elements, "/>\n");
  g_string_free(path_data, TRUE);
}

static void motiva_renderer_draw_glyph(
  PangoRenderer *base,
  PangoFont *font,
  PangoGlyph glyph,
  double x,
  double y
) {
  MotivaPangoSvgRenderer *renderer = (MotivaPangoSvgRenderer *)base;
  PangoGlyphInfo info;
  memset(&info, 0, sizeof(PangoGlyphInfo));
  info.glyph = glyph;
  motiva_append_glyph_path(
    renderer,
    renderer->elements,
    font,
    info,
    x,
    y,
    motiva_renderer_color(renderer, PANGO_RENDER_PART_FOREGROUND),
    motiva_renderer_alpha(renderer, PANGO_RENDER_PART_FOREGROUND)
  );
}

static void motiva_renderer_draw_shape(
  PangoRenderer *base,
  PangoAttrShape *attribute,
  int x,
  int y
) {
  (void)attribute;
  (void)x;
  (void)y;
  motiva_renderer_fail(
    (MotivaPangoSvgRenderer *)base,
    "Pango shape attributes are not supported"
  );
}

static void motiva_pango_svg_renderer_class_init(
  MotivaPangoSvgRendererClass *class
) {
  PangoRendererClass *renderer_class = PANGO_RENDERER_CLASS(class);
  renderer_class->draw_glyph_item = motiva_renderer_draw_glyph_item;
  renderer_class->draw_rectangle = motiva_renderer_draw_rectangle;
  renderer_class->draw_error_underline = motiva_renderer_draw_error_underline;
  renderer_class->draw_trapezoid = motiva_renderer_draw_trapezoid;
  renderer_class->draw_glyph = motiva_renderer_draw_glyph;
  renderer_class->draw_shape = motiva_renderer_draw_shape;
  renderer_class->prepare_run = motiva_renderer_prepare_run;
}

static void motiva_pango_svg_renderer_init(
  MotivaPangoSvgRenderer *renderer
) {
  renderer->render = NULL;
  renderer->cairo = NULL;
  renderer->elements = NULL;
  renderer->origin_x = 0.0;
  renderer->origin_y = 0.0;
  renderer->base_color.red = 65535;
  renderer->base_color.green = 65535;
  renderer->base_color.blue = 65535;
  renderer->base_alpha = 65535;
  for (int part = 0; part < 5; part += 1) {
    renderer->colors[part] = renderer->base_color;
    renderer->alphas[part] = renderer->base_alpha;
  }
  renderer->failed = FALSE;
}

static gboolean motiva_render_svg(
  PangoLayout *layout,
  const MotivaPangoJob *job,
  cairo_t *cairo,
  double width,
  double height,
  double origin_x,
  double origin_y,
  MotivaPangoRender *render
) {
  GString *elements = g_string_new(NULL);
  MotivaPangoSvgRenderer *renderer = g_object_new(
    motiva_pango_svg_renderer_get_type(),
    NULL
  );
  renderer->render = render;
  renderer->cairo = cairo;
  renderer->elements = elements;
  renderer->origin_x = origin_x;
  renderer->origin_y = origin_y;

  renderer->base_color.red = motiva_color_channel(job->red);
  renderer->base_color.green = motiva_color_channel(job->green);
  renderer->base_color.blue = motiva_color_channel(job->blue);
  renderer->base_alpha = motiva_color_channel(job->alpha);
  for (int part = 0; part < 5; part += 1) {
    renderer->colors[part] = renderer->base_color;
    renderer->alphas[part] = renderer->base_alpha;
  }
  pango_renderer_activate(PANGO_RENDERER(renderer));
  pango_renderer_draw_layout(PANGO_RENDERER(renderer), layout, 0, 0);
  pango_renderer_deactivate(PANGO_RENDERER(renderer));

  gboolean success = !renderer->failed;
  if (success) {
    GString *document = g_string_new(
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""
    );
    motiva_svg_append_number(document, width);
    g_string_append(document, "\" height=\"");
    motiva_svg_append_number(document, height);
    g_string_append(document, "\" viewBox=\"0 0 ");
    motiva_svg_append_number(document, width);
    g_string_append_c(document, ' ');
    motiva_svg_append_number(document, height);
    g_string_append(document, "\">\n");
    g_string_append_len(document, elements->str, (gssize)elements->len);
    g_string_append(document, "</svg>\n");
    if (document->len > INT32_MAX) {
      motiva_render_error(
        render,
        MOTIVA_PANGO_CAIRO_ERROR,
        "SVG output exceeds the MoonBit byte-array limit"
      );
      success = FALSE;
      g_string_free(document, TRUE);
    } else {
      g_free(render->svg);
      render->svg_length = (int32_t)document->len;
      render->svg = g_string_free(document, FALSE);
    }
  }
  g_object_unref(renderer);
  g_string_free(elements, TRUE);
  return success;
}

static MotivaPangoRender *motiva_pango_job_render_locked(
  MotivaPangoEngine *engine,
  MotivaPangoJob *job
) {
  MotivaPangoRender *render = motiva_render_new();
  if (engine->font_map == NULL) {
    motiva_render_error(render, MOTIVA_PANGO_LAYOUT_ERROR, "missing Pango font map");
    return render;
  }
  cairo_surface_t *recording = cairo_recording_surface_create(
    CAIRO_CONTENT_COLOR_ALPHA,
    NULL
  );
  cairo_t *measure_context = cairo_create(recording);
  cairo_status_t cairo_status_value = cairo_status(measure_context);
  if (cairo_status_value != CAIRO_STATUS_SUCCESS) {
    motiva_render_error(
      render,
      MOTIVA_PANGO_CAIRO_ERROR,
      cairo_status_to_string(cairo_status_value)
    );
    cairo_destroy(measure_context);
    cairo_surface_destroy(recording);
    return render;
  }

  PangoLayout *layout = NULL;
  char *plain_text = NULL;
  if (!motiva_configure_layout(
        engine,
        job,
        measure_context,
        &layout,
        &plain_text,
        render
      )) {
    cairo_destroy(measure_context);
    cairo_surface_destroy(recording);
    return render;
  }

  PangoRectangle ink;
  PangoRectangle logical;
  pango_layout_get_extents(layout, &ink, &logical);
  render->ink_x = motiva_pango_units(ink.x);
  render->ink_y = motiva_pango_units(ink.y);
  render->ink_width = motiva_pango_units(ink.width);
  render->ink_height = motiva_pango_units(ink.height);
  render->logical_x = motiva_pango_units(logical.x);
  render->logical_y = motiva_pango_units(logical.y);
  render->logical_width = motiva_pango_units(logical.width);
  render->logical_height = motiva_pango_units(logical.height);
  render->baseline = motiva_pango_units(pango_layout_get_baseline(layout));
  render->unknown_glyphs = pango_layout_get_unknown_glyphs_count(layout);
  size_t text_length = strlen(plain_text);
  if (text_length > INT32_MAX) {
    motiva_render_error(
      render,
      MOTIVA_PANGO_LAYOUT_ERROR,
      "plain text exceeds the MoonBit byte-array limit"
    );
    g_free(plain_text);
    g_object_unref(layout);
    cairo_destroy(measure_context);
    cairo_surface_destroy(recording);
    return render;
  }
  g_free(render->text);
  render->text = g_strdup(plain_text);
  render->text_length = (int32_t)text_length;
  motiva_collect_lines(layout, render);

  double min_x = MIN(render->ink_x, render->logical_x);
  double min_y = MIN(render->ink_y, render->logical_y);
  double max_x = MAX(
    render->ink_x + render->ink_width,
    render->logical_x + render->logical_width
  );
  double max_y = MAX(
    render->ink_y + render->ink_height,
    render->logical_y + render->logical_height
  );
  const double padding = 1.0;
  double surface_width = ceil(MAX(1.0, max_x - min_x + 2.0 * padding));
  double surface_height = ceil(MAX(1.0, max_y - min_y + 2.0 * padding));
  double origin_x = padding - min_x;
  double origin_y = padding - min_y;
  gboolean rendered = motiva_render_svg(
    layout,
    job,
    measure_context,
    surface_width,
    surface_height,
    origin_x,
    origin_y,
    render
  );

  g_free(plain_text);
  g_object_unref(layout);
  cairo_destroy(measure_context);
  cairo_surface_destroy(recording);
  if (rendered) {
    render->status = MOTIVA_PANGO_OK;
  }
  return render;
}

MOONBIT_FFI_EXPORT
MotivaPangoRender *motiva_pango_job_render(
  MotivaPangoEngine *engine,
  MotivaPangoJob *job
) {
  g_mutex_lock(&engine->lock);
  MotivaPangoRender *render = motiva_pango_job_render_locked(engine, job);
  g_mutex_unlock(&engine->lock);
  return render;
}

MOONBIT_FFI_EXPORT
int32_t motiva_pango_render_status(const MotivaPangoRender *render) {
  return render->status;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t motiva_pango_render_message(const MotivaPangoRender *render) {
  return motiva_make_bytes(render->message, strlen(render->message));
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t motiva_pango_render_svg(const MotivaPangoRender *render) {
  return motiva_make_bytes(render->svg, (size_t)render->svg_length);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t motiva_pango_render_text(const MotivaPangoRender *render) {
  return motiva_make_bytes(render->text, (size_t)render->text_length);
}

MOONBIT_FFI_EXPORT
void motiva_pango_render_metrics(
  const MotivaPangoRender *render,
  double *ink_x,
  double *ink_y,
  double *ink_width,
  double *ink_height,
  double *logical_x,
  double *logical_y,
  double *logical_width,
  double *logical_height,
  double *baseline,
  int32_t *unknown_glyphs,
  int32_t *glyph_count,
  int32_t *line_count
) {
  *ink_x = render->ink_x;
  *ink_y = render->ink_y;
  *ink_width = render->ink_width;
  *ink_height = render->ink_height;
  *logical_x = render->logical_x;
  *logical_y = render->logical_y;
  *logical_width = render->logical_width;
  *logical_height = render->logical_height;
  *baseline = render->baseline;
  *unknown_glyphs = render->unknown_glyphs;
  *glyph_count = render->glyph_count;
  *line_count = render->lines == NULL ? 0 : (int32_t)render->lines->len;
}

MOONBIT_FFI_EXPORT
int32_t motiva_pango_render_cluster_count(const MotivaPangoRender *render) {
  return render->clusters == NULL ? 0 : (int32_t)render->clusters->len;
}

MOONBIT_FFI_EXPORT
int32_t motiva_pango_render_cluster(
  const MotivaPangoRender *render,
  int32_t index,
  int32_t *source_start,
  int32_t *source_end,
  int32_t *glyph_start,
  int32_t *glyph_end,
  int32_t *line_index,
  int32_t *bidi_level,
  double *x,
  double *y,
  double *width,
  double *height
) {
  if (index < 0 || render->clusters == NULL || index >= (int32_t)render->clusters->len) {
    return 0;
  }
  MotivaPangoCluster *cluster = &g_array_index(
    render->clusters,
    MotivaPangoCluster,
    index
  );
  *source_start = cluster->source_start;
  *source_end = cluster->source_end;
  *glyph_start = cluster->glyph_start;
  *glyph_end = cluster->glyph_end;
  *line_index = cluster->line_index;
  *bidi_level = cluster->bidi_level;
  *x = cluster->x;
  *y = cluster->y;
  *width = cluster->width;
  *height = cluster->height;
  return 1;
}

MOONBIT_FFI_EXPORT
int32_t motiva_pango_render_line_count(const MotivaPangoRender *render) {
  return render->lines == NULL ? 0 : (int32_t)render->lines->len;
}

MOONBIT_FFI_EXPORT
int32_t motiva_pango_render_line(
  const MotivaPangoRender *render,
  int32_t index,
  int32_t *source_start,
  int32_t *source_end,
  double *ink_x,
  double *ink_y,
  double *ink_width,
  double *ink_height,
  double *logical_x,
  double *logical_y,
  double *logical_width,
  double *logical_height,
  double *baseline
) {
  if (index < 0 || render->lines == NULL || index >= (int32_t)render->lines->len) {
    return 0;
  }
  MotivaPangoLine *line = &g_array_index(
    render->lines,
    MotivaPangoLine,
    index
  );
  *source_start = line->source_start;
  *source_end = line->source_end;
  *ink_x = line->ink_x;
  *ink_y = line->ink_y;
  *ink_width = line->ink_width;
  *ink_height = line->ink_height;
  *logical_x = line->logical_x;
  *logical_y = line->logical_y;
  *logical_width = line->logical_width;
  *logical_height = line->logical_height;
  *baseline = line->baseline;
  return 1;
}
