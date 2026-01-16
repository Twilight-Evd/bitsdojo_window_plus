#include "include/bitsdojo_window_windows/multi_window_manager.h"
#include <flutter/encodable_value.h>
#include <flutter/method_call.h>
#include <flutter/standard_method_codec.h>

MultiWindowManager &MultiWindowManager::GetInstance() {
  static MultiWindowManager instance;
  return instance;
}

void MultiWindowManager::SetWindowFactory(WindowFactory factory) {
  std::lock_guard<std::recursive_mutex> lock(mutex_);
  window_factory_ = factory;
}

void MultiWindowManager::OpenNewWindow(const char *name, const char *arguments,
                                       double width, double height, double x,
                                       double y) {
  std::string name_str = name ? name : "";

  // Default size if not specified
  int w = (width == 0) ? 1280 : static_cast<int>(width);
  int h = (height == 0) ? 720 : static_cast<int>(height);

  {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    // Check if named window already exists
    if (!name_str.empty()) {
      auto it = windows_.find(name_str);
      if (it != windows_.end()) {
        HWND hwnd = it->second;
        if (IsWindow(hwnd)) {
          // Restore and activate existing window
          if (IsIconic(hwnd)) {
            ShowWindow(hwnd, SW_RESTORE);
          }
          SetForegroundWindow(hwnd);

          // Send updated arguments to existing window
          SendArgumentsUpdate(hwnd, arguments);
          return;
        } else {
          // Window was destroyed, clean up mapping
          windows_.erase(it);
          window_names_.erase(hwnd);
        }
      }
    }

    // Create new window
    if (!window_factory_) {
      // Error: No window factory set
      OutputDebugStringA("[MultiWindowManager] ERROR: No window factory set\n");
      return;
    }

    // Set pending info before calling factory so RegisterWithRegistrar can pick
    // it up
    pending_name_ = name_str;
    pending_arguments_ = arguments ? arguments : "";
  } // Lock released here to avoid deadlock

  // Create window via factory (RegisterWithRegistrar will be called inside
  // here)
  HWND hwnd = window_factory_(L"Vidra", // TODO: Make configurable
                              static_cast<int>(x), static_cast<int>(y),
                              static_cast<int>(w), static_cast<int>(h), name,
                              arguments);

  {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    // Clear pending info
    pending_name_ = "";
    pending_arguments_ = "";

    if (hwnd && !name_str.empty()) {
      windows_[name_str] = hwnd;
      window_names_[hwnd] = name_str;

      char debug_msg[256];
      sprintf_s(debug_msg,
                "[MultiWindowManager] Created window: %s (HWND: %p)\n",
                name_str.c_str(), hwnd);
      OutputDebugStringA(debug_msg);
    }
  }
}

std::string MultiWindowManager::GetPendingName() {
  std::lock_guard<std::recursive_mutex> lock(mutex_);
  return pending_name_;
}

std::string MultiWindowManager::GetPendingArguments() {
  std::lock_guard<std::recursive_mutex> lock(mutex_);
  return pending_arguments_;
}

void MultiWindowManager::SendArgumentsUpdate(HWND window,
                                             const char *arguments) {
  if (!window || !arguments)
    return;

  std::lock_guard<std::recursive_mutex> lock(mutex_);
  auto it = message_senders_.find(window);
  if (it != message_senders_.end()) {
    it->second(arguments);
  } else {
    char debug_msg[256];
    sprintf_s(
        debug_msg,
        "[MultiWindowManager] No message sender registered for HWND: %p\n",
        window);
    OutputDebugStringA(debug_msg);
  }
}

void MultiWindowManager::RegisterMessageSender(HWND window,
                                               MessageSender sender) {
  std::lock_guard<std::recursive_mutex> lock(mutex_);
  message_senders_[window] = sender;
}

void MultiWindowManager::CloseWindow(const std::string &name) {
  std::lock_guard<std::recursive_mutex> lock(mutex_);

  auto it = windows_.find(name);
  if (it != windows_.end()) {
    HWND hwnd = it->second;
    if (IsWindow(hwnd)) {
      DestroyWindow(hwnd);
    }
    window_names_.erase(hwnd);
    windows_.erase(it);
  }
}

HWND MultiWindowManager::GetWindow(const std::string &name) {
  std::lock_guard<std::recursive_mutex> lock(mutex_);

  auto it = windows_.find(name);
  return (it != windows_.end()) ? it->second : nullptr;
}

void MultiWindowManager::OnWindowDestroyed(HWND window) {
  std::lock_guard<std::recursive_mutex> lock(mutex_);

  // Find and remove from mappings
  auto name_it = window_names_.find(window);
  if (name_it != window_names_.end()) {
    std::string name = name_it->second;
    windows_.erase(name);
    window_names_.erase(name_it);
    message_senders_.erase(window); // Clean up sender

    char debug_msg[256];
    sprintf_s(debug_msg,
              "[MultiWindowManager] Window destroyed: %s (HWND: %p)\n",
              name.c_str(), window);
    OutputDebugStringA(debug_msg);
  }
}

void MultiWindowManager::RegisterWindow(HWND window, const std::string &name) {
  std::lock_guard<std::recursive_mutex> lock(mutex_);

  if (!name.empty() && window) {
    windows_[name] = window;
    window_names_[window] = name;
  }
}
