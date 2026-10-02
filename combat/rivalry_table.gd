class_name RivalryTable
extends Resource
## Todas las rivalidades y sinergias. Se edita en res://combat/rivalries.tres.

@export var entries: Array[RivalryData] = []


func find(first: StringName, second: StringName) -> RivalryData:
	if first == second:
		return null
	for entry in entries:
		if entry.involves(first, second):
			return entry
	return null
