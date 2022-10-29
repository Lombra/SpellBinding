# SpellBinding

SpellBinding is a powerful keybinding tool, fully utilising the power of AceDB datatypes. It lets you bind spells, macros and items without placing them on an action button. The use of binding sets allows for very flexible configurations.

All bindings set using this addon are override bindings, which means they exist as an extra layer on top of the regular bindings and only when the addon is loaded. Regular bindings will never be undone as a result of binding with this addon.

Open the addon using either of the following commands:

- `/spellbinding`
- `/sb`

### **Bindings**

Drag spells, macros and items onto the frame to include them in the list. If you drag something onto an existing binding or header, its binding set will be selected for the new binding. Click an item in the list to set a binding and a binding set for it. (read more about binding sets below) If you want to bind a mouse button, make sure to click within the bounds of the frame.

You can bind the clicking of a button frame by clicking the Bind click button, and clicking the desired button frame using the mouse button that you want to be used in the keybinding.

### **Binding sets**

Binding sets allows you to set up sets of bindings based on a number of predetermined AceDB datatypes. You may for example specify a set of global bindings that's applied for all characters, as well as individual character bindings that are applied on top of the global ones.

Available sets include:

- **Global** - shared by all characters
- **Faction** - shared by all characters of your current faction
- **Faction - realm** - shared by all characters of your current faction and realm
- **Realm** - shared by all characters on your current realm
- **Race** - shared by all characters of your current race
- **Class** - shared by all characters of your current class
- **Character** - used by the current character only
- **Profile** - for the profile selected in the Profile tab

The Character set only applies bindings to the current character, the Realm set only applies to characters on the current realm, and so on.

You may define the priority of the binding sets to determine how to solve binding conflicts. For example, you may want global bindings to override character specific ones, instead of the opposite. Move sets up and down in the Binding sets tab to modify their priorities. The higher a set is placed in the list, the higher its priority.

### **Profile**

The Profile tab determines which profile is used when using the Profile binding set.

### **Grid**

The Grid tab is an alternative to the Bindings tab view that lets you view bindings by key instead of by spell. You may define how many and which keys are to be shown. You may for example set it up to display all your num pad bindings, your mouse buttons or something completely different.

Bind items in this interface by dragging them to the desired button.
