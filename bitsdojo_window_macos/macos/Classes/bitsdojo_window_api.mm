#import "bitsdojo_window_api.h"
#import "bitsdojo_window.h"

BDWPrivateAPI privateAPI = {
    windowCanBeShown,
    setAppWindow,
    appWindowIsSet,
};

BDWPublicAPI publicAPI = {
    getAppWindow,
    setWindowCanBeShown,
    setInsideDoWhenWindowReady,
    showWindow,
    hideWindow,
    moveWindow,
    setSize,
    setMinSize,
    setMaxSize,
    getScreenInfoForWindow,
    setPositionForWindow,
    setRectForWindow,
    getRectForWindow,
    isWindowVisible,
    isWindowMaximized,
    maximizeOrRestoreWindow,
    maximizeWindow,
    toggleFullScreen,
    minimizeWindow,
    closeWindow,
    setWindowTitle,
    getTitleBarHeight,
    setAlwaysOnTop,
    .isAlwaysOnTop = isAlwaysOnTop,
    .setBackgroundEffect = (TSetBackgroundEffect)setBackgroundEffect,
    .setTitleBarHeight = (TSetTitleBarHeight)setTitleBarHeight,
    isPrimaryWindow,
    terminateApp,
    setWindowButtonVisibility,
    setWindowButtonOffset,
};

BDWAPI bdwAPI = {
    &publicAPI,
    &privateAPI,
};

BDW_EXPORT BDWAPI *bitsdojo_window_api() { return &bdwAPI; }
