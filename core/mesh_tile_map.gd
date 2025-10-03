@tool
class_name MeshTileMap extends Node2D

@export_range(1, 100, 1) var wide := 3

var multimesh: MultiMesh

func _ready() -> void:
    _reset()

func _reset() -> void:
    var multimesh_inst := $MultiMeshInstance2D as MultiMeshInstance2D
    multimesh = multimesh_inst.multimesh
    multimesh.instance_count = 0
    multimesh.visible_instance_count = -1
    multimesh.use_colors = true
    multimesh.use_custom_data = true
    multimesh.transform_format = MultiMesh.TRANSFORM_2D

    multimesh.instance_count = wide * wide
    for y in range(0, wide):
        for x in range(0, wide):
            var i := x + y * wide
            var t2d := global_transform
            t2d.origin += Vector2(16 * x, 16 * y)
            multimesh.set_instance_transform_2d(i, t2d)
            multimesh.set_instance_color(i, Color8(x, y, 0, 1))