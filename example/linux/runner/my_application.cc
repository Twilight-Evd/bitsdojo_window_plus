#include <bitsdojo_window_linux/bitsdojo_window_plugin.h>
#include <glib.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/prctl.h>
#include <signal.h>

#include "flutter/generated_plugin_registrant.h"
#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

struct _MyApplication {
  GtkApplication parent_instance;
  char **dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static char **g_dart_entrypoint_arguments = nullptr;

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication *self, FlView *view) {
  g_print("*** [%d] first_frame_cb called! Showing window... ***\n", getpid());
  fflush(stdout);
  GtkWindow *window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  gtk_widget_show(GTK_WIDGET(window));
  gtk_window_present(window);
}

static void onOpenNewWindow(const char *name, const char *args, double width,
                            double height, double x, double y) {
  g_print("=== onOpenNewWindow called! ===\n");
  fflush(stdout);
  g_print("  name: %s, args: %s, size: %.fx%.f, pos: %.f,%.f\n",
          name ? name : "NULL", args ? args : "NULL", width, height, x, y);
  fflush(stdout);

  char exePath[1024];
  ssize_t len = readlink("/proc/self/exe", exePath, sizeof(exePath) - 1);
  if (len != -1) {
    exePath[len] = '\0';
  } else {
    g_warning("Could not determine executable path");
    return;
  }

  // Construct arguments for the new process
  GPtrArray *argv = g_ptr_array_new_with_free_func(g_free);
  g_ptr_array_add(argv, g_strdup(exePath));

  // Pass along the original arguments (e.g., assets paths in debug mode)
  if (g_dart_entrypoint_arguments) {
    int count = g_strv_length(g_dart_entrypoint_arguments);
    for (int i = 0; i < count; i++) {
      const char *arg = g_dart_entrypoint_arguments[i];
      g_ptr_array_add(argv, g_strdup(arg));
    }
  }
  g_ptr_array_add(argv, NULL);

  // Set environment variables for the child process
  g_auto(GStrv) envp = g_get_environ();

  // Strip FLUTTER_ENGINE_SWITCH environment variables
  // These are often passed by the debugger (e.g. start-paused=true)
  // and would prevent the child process from running main() immediately.
  for (int i = 1; i <= 20; i++) {
    char key[64];
    sprintf(key, "FLUTTER_ENGINE_SWITCH_%d", i);
    envp = g_environ_unsetenv(envp, key);
  }
  envp = g_environ_unsetenv(envp, "FLUTTER_ENGINE_SWITCHES");

  const char *currentDepthStr = g_environ_getenv(envp, "BDW_DEPTH");
  int currentDepth = currentDepthStr ? atoi(currentDepthStr) : 0;
  char depthStr[32];
  sprintf(depthStr, "%d", currentDepth + 1);
  envp = g_environ_setenv(envp, "BDW_DEPTH", depthStr, TRUE);
  if (name) {
    envp = g_environ_setenv(envp, "BDW_NAME", name, TRUE);
  }
  if (args) {
    envp = g_environ_setenv(envp, "BDW_ARGS", args, TRUE);
  }

  char widthStr[32], heightStr[32], xStr[32], yStr[32];
  sprintf(widthStr, "%.f", width);
  sprintf(heightStr, "%.f", height);
  sprintf(xStr, "%.f", x);
  sprintf(yStr, "%.f", y);
  envp = g_environ_setenv(envp, "BDW_WIDTH", widthStr, TRUE);
  envp = g_environ_setenv(envp, "BDW_HEIGHT", heightStr, TRUE);
  envp = g_environ_setenv(envp, "BDW_X", xStr, TRUE);
  envp = g_environ_setenv(envp, "BDW_Y", yStr, TRUE);

  g_print("Spawning child process (Depth: %d)...\n", currentDepth + 1);
  fflush(stdout);
  GError *error = NULL;
  GPid child_pid;
  if (!g_spawn_async(NULL, (gchar **)argv->pdata, envp,
                     G_SPAWN_DO_NOT_REAP_CHILD, NULL, NULL, &child_pid,
                     &error)) {
    g_warning("Failed to spawn child process: %s", error->message);
    g_error_free(error);
  } else {
    g_print("=== Spawned child process! PID: %d ===\n", (int)child_pid);
    fflush(stdout);
  }
  g_ptr_array_unref(argv);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication *application) {
  MyApplication *self = MY_APPLICATION(application);

  GList *windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows != NULL) {
    gtk_window_present(GTK_WINDOW(windows->data));
    return;
  }

  GtkWindow *window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen *screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar *wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar *header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "example");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "example");
  }

  auto bdw = bitsdojo_window_from(window);
  bdw->setCustomFrame(true);

  bitsdojo_window_set_on_open_new_window(onOpenNewWindow);

  // Set window size/position from environment
  const char *w_str = getenv("BDW_WIDTH");
  const char *h_str = getenv("BDW_HEIGHT");
  const char *x_str = getenv("BDW_X");
  const char *y_str = getenv("BDW_Y");

  int width = (w_str && atoi(w_str) > 0) ? atoi(w_str) : 800;
  int height = (h_str && atoi(h_str) > 0) ? atoi(h_str) : 600;

  gtk_window_set_default_size(window, width, height);

  if (x_str && y_str) {
    gtk_window_move(window, atoi(x_str), atoi(y_str));
  }

  const char *depth_str = getenv("BDW_DEPTH");
  if (depth_str && atoi(depth_str) > 0) {
    // Child process: setup death signal so we exit when parent dies
    prctl(PR_SET_PDEATHSIG, SIGTERM);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();

  if (self->dart_entrypoint_arguments) {
    fl_dart_project_set_dart_entrypoint_arguments(
        project, self->dart_entrypoint_arguments);
  }

  FlView *view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);

  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  gtk_widget_show(GTK_WIDGET(view));

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_realize(GTK_WIDGET(view));
  gtk_widget_grab_focus(GTK_WIDGET(view));

  gtk_widget_realize(GTK_WIDGET(window));
}

static void my_application_dispose(GObject *object) {
  MyApplication *self = MY_APPLICATION(object);
  g_strfreev(self->dart_entrypoint_arguments);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static int
my_application_command_line(GApplication *application,
                            GApplicationCommandLine *command_line) {
  g_application_activate(application);

  const gchar *const *envp = g_application_command_line_get_environ(command_line);
  const char *args = g_environ_getenv((gchar **)envp, "BDW_ARGS");
  if (args) {
    bitsdojo_window_update_arguments(args);
  }

  GtkWindow *window = gtk_application_get_active_window(GTK_APPLICATION(application));
  if (window) {
    gtk_window_present(window);
  }

  return 0;
}

extern "C" gboolean my_application_local_command_line(GApplication *application,
                                                      gchar ***arguments,
                                                      int *exit_status) {
  MyApplication *self = MY_APPLICATION(application);

  if (self->dart_entrypoint_arguments) {
    g_strfreev(self->dart_entrypoint_arguments);
  }
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);
  g_dart_entrypoint_arguments = self->dart_entrypoint_arguments;

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  return FALSE;
}

static void my_application_class_init(MyApplicationClass *klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication *self) {
}

MyApplication *my_application_new(int argc, char **argv) {
  const char *depthStr = getenv("BDW_DEPTH");
  int depth = depthStr ? atoi(depthStr) : 0;
  const char *name = getenv("BDW_NAME");

  MyApplication *self;
  GApplicationFlags flags = G_APPLICATION_DEFAULT_FLAGS;

  char appId[128];
  if (depth == 0) {
    sprintf(appId, "com.example.example");
  } else {
    if (name) {
      sprintf(appId, "com.example.example.n.%s", name);
      flags = (GApplicationFlags)(G_APPLICATION_HANDLES_COMMAND_LINE |
                                   G_APPLICATION_SEND_ENVIRONMENT);
    } else {
      sprintf(appId, "com.example.example.p%d", getpid());
      flags = G_APPLICATION_NON_UNIQUE;
    }
  }

  self = MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", appId, "flags", flags,
                                     nullptr));

  if (argc > 1) {
    self->dart_entrypoint_arguments = g_strdupv(argv + 1);
    g_dart_entrypoint_arguments = self->dart_entrypoint_arguments;
  }

  return self;
}
