// Dash to Dock lists Shell.AppSystem.get_running() as-is, and a Wayland window can't
// mark itself skip-taskbar, so the launcher is filtered out of that list instead.
import Shell from 'gi://Shell';
import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';

const isVicinae = app => {
    const windows = app.get_windows();
    return windows.length > 0 &&
        windows.every(w => w.get_wm_class()?.toLowerCase() === 'vicinae');
};

export default class HideVicinaeFromDock extends Extension {
    enable() {
        this._injections = new InjectionManager();
        this._injections.overrideMethod(Shell.AppSystem.prototype, 'get_running',
            original => function () {
                return original.call(this).filter(app => !isVicinae(app));
            });
    }

    disable() {
        this._injections.clear();
        this._injections = null;
    }
}
