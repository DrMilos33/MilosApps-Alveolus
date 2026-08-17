class_name CombatTagCatalog
extends RefCounted

## Canonical lowercase vocabulary for treatment and active-ability context.
## Aliases are accepted only at content import boundaries.

const ALIASES := {
	"samples": "sample",
	"therapy": "treatment",
	"defence": "defense",
}

const KNOWN := [
	"active",
	"area",
	"control",
	"defense",
	"defensive",
	"diagnosis",
	"focus",
	"line",
	"marked",
	"piercing",
	"precise",
	"sample",
	"spread",
	"support",
	"tracking",
	"treatment",
]


static func normalize(tags: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for raw_tag in tags:
		var tag := raw_tag.strip_edges().to_lower().replace(" ", "_")
		tag = String(ALIASES.get(tag, tag))
		if not tag.is_empty() and not result.has(tag):
			result.append(tag)
	return result


static func validate(tags: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	var normalized := normalize(tags)
	for tag in normalized:
		if not KNOWN.has(tag):
			errors.append(tag)
	return errors
