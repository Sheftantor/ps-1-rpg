# Downscales every enemy portrait source to UI icon size:
#   godot --headless --path . -s res://scripts/tools/build_portrait_icons.gd
#   godot --headless --path . --import
#
#   res://Import/art/portrait/source/<name>.png|jpg -> res://textures/ui/icons/<name>.png
#
# Sources are the 1024x1024 originals (the folder has a .gdignore, so they're
# kept but never imported or exported). Resampling is Lanczos, done once here:
# a 1024 texture shrunk with nearest filtering at runtime shimmers. Each output
# gets the same import settings as the item icons (lossless, no mipmaps). The
# second command imports the new PNGs. Rules for new portraits:
# docs/enemy_portraits.md.
extends SceneTree

const SOURCE_DIR := "res://Import/art/portrait/source/"
const OUTPUT_DIR := "res://textures/ui/icons/"
## Item icon size (textures/ui/icons/*.png).
const ICON_SIZE := 64
## Import settings copied from the item icons.
const IMPORT_TEMPLATE := "res://textures/ui/icons/placeholder_item.png.import"


func _init() -> void:
	var template := ConfigFile.new()
	if template.load(IMPORT_TEMPLATE) != OK:
		push_error("Can't read %s" % IMPORT_TEMPLATE)
		quit(1)
		return
	for file in DirAccess.get_files_at(SOURCE_DIR):
		if file.get_extension().to_lower() not in ["png", "jpg", "jpeg", "webp"]:
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + file))
		if image == null:
			push_error("Can't load %s" % file)
			continue
		image.convert(Image.FORMAT_RGBA8)
		var from := image.get_size()
		image.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
		var out := OUTPUT_DIR + file.get_basename() + ".png"
		image.save_png(out)
		_write_import(template, out)
		print("%s %dx%d -> %s %dx%d" % [file, from.x, from.y, out, ICON_SIZE, ICON_SIZE])
	quit()


## The item icons' [params], so the importer treats this PNG the same way. An
## existing .import keeps its uid, so references to the icon survive a rerun.
func _write_import(template: ConfigFile, png: String) -> void:
	var config := ConfigFile.new()
	if config.load(png + ".import") != OK:
		config.set_value("remap", "importer", "texture")
		config.set_value("remap", "type", "CompressedTexture2D")
	for key in template.get_section_keys("params"):
		config.set_value("params", key, template.get_value("params", key))
	config.save(png + ".import")
