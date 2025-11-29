extends Node

"""Knowledge graph helper.
Provides simple loading and keyword-based querying over `user://memory_graph.json`.
"""

func load_graph() -> Array:
	var filepath = "user://memory_graph.json"
	if not FileAccess.file_exists(filepath):
		return []

	var f = FileAccess.open(filepath, FileAccess.READ)
	if not f:
		return []

	var content = f.get_as_text()
	f.close()

	var j = JSON.new()
	if j.parse(content) != OK:
		return []

	var data = j.data
	if data.has("graphs") and typeof(data.graphs) == TYPE_ARRAY:
		return data.graphs
	return []


func query_by_keywords(keywords: Array, top_k: int = 6) -> Array:
	"""Return top_k graph entries that match any of the keywords.

	Matching is simple substring check in S, P, O (case-insensitive). Results are
	scored by number of keyword matches and importance `I`.
	"""
	var graphs = load_graph()
	if graphs.is_empty() or keywords.is_empty():
		return []

	var kws = []
	for k in keywords:
		kws.append(str(k).to_lower())

	var scored = []
	for g in graphs:
		var s = str(g.get("S", "")).to_lower()
		var p = str(g.get("P", "")).to_lower()
		var o = str(g.get("O", "")).to_lower()
		var match_count = 0
		for kw in kws:
			if kw == "":
				continue
			if s.find(kw) != -1:
				match_count += 1
			elif p.find(kw) != -1:
				match_count += 1
			elif o.find(kw) != -1:
				match_count += 1

		if match_count > 0:
			var imp = int(g.get("I", 1)) if typeof(g.get("I", 1)) in [TYPE_INT, TYPE_FLOAT] else 1
			var score = float(match_count) * (1.0 + float(imp) / 10.0)
			scored.append({"entry": g, "score": score, "importance": imp})

	if scored.is_empty():
		return []

	scored.sort_custom(func(a, b): return a.score > b.score)

	var results = []
	for i in range(min(top_k, scored.size())):
		results.append(scored[i].entry)

	return results
