class_name Stamps
## Achievements earned when the crown is taken.

const LOVERS := "stamp_lovers"
const CLEAR := "stamp_clear"
const EGG := "stamp_egg"
const PACIFIST := "stamp_pacifist"
const ALL: Array[String] = [LOVERS, CLEAR, EGG, PACIFIST]
const DESCRIPTIONS := {
	LOVERS: ["lovers", "survive"],
	CLEAR: ["clear", "board"],
	EGG: ["future", "generation"],
	PACIFIST: ["rat", "pacifist"],
}


static func earned(board: Board, killed_rats: int) -> Array[String]:
	var out: Array[String] = []
	var living := 0
	for t in board.tiles:
		if t.is_empty() or t.kind == Kind.DRAGON or t.kind == Kind.CROWN:
			continue
		living += 1
	if living == 0:
		out.append(CLEAR)
	var giants_alive := 0
	for g in board.all_of(Kind.GIANT):
		if not g.defeated:
			giants_alive += 1
	if giants_alive == 2:
		out.append(LOVERS)
	var egg := board.first_of(Kind.DRAGON_EGG)
	if egg != null and not egg.defeated:
		out.append(EGG)
	if killed_rats == 0:
		out.append(PACIFIST)
	return out
