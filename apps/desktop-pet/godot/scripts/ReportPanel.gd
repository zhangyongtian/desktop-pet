class_name ReportPanel
extends Control

@onready var summarize_button: Button = %SummarizeButton
@onready var daily_button: Button = %DailyButton
@onready var weekly_button: Button = %WeeklyButton
@onready var monthly_button: Button = %MonthlyButton
@onready var semiannual_button: Button = %SemiannualButton
@onready var output_edit: TextEdit = %OutputEdit

var _pipeline: SummarizationPipeline = null
var _report: ReportGenerator = null


func _ready() -> void:
	_pipeline = _find_pipeline()
	_report = _find_report_generator()

	summarize_button.pressed.connect(func() -> void:
		output_edit.text = "正在总结…"
		var r := await _pipeline.run_if_needed(true)
		if bool(r.get("ok", false)):
			if bool(r.get("skipped", false)):
				output_edit.text = _friendly_reason(String(r.get("reason", "")))
			else:
				output_edit.text = String(r.get("content", ""))
		else:
			output_edit.text = "总结失败：" + _friendly_error(String(r.get("error", "")))
	)

	daily_button.pressed.connect(func() -> void:
		await _gen("daily")
	)
	weekly_button.pressed.connect(func() -> void:
		await _gen("weekly")
	)
	monthly_button.pressed.connect(func() -> void:
		await _gen("monthly")
	)
	semiannual_button.pressed.connect(func() -> void:
		await _gen("semiannual")
	)


func _gen(kind: String) -> void:
	if _report == null:
		output_edit.text = "缺少 ReportGenerator"
		return
	output_edit.text = "正在生成…"
	var r := await _report.generate(kind)
	if bool(r.get("ok", false)):
		output_edit.text = String(r.get("content", ""))
	else:
		output_edit.text = "生成失败：" + _friendly_error(String(r.get("error", "")))


func _friendly_reason(reason: String) -> String:
	var r := reason.strip_edges()
	if r == "missing_api_key":
		return "DeepSeek 未配置：请到【设置】填写 API Key，然后再运行总结。"
	if r == "missing_endpoint":
		return "DeepSeek Endpoint 为空：请到【设置】填写 Endpoint。"
	if r == "missing_model":
		return "DeepSeek Model 为空：请到【设置】填写 Model。"
	if r == "cooldown":
		return "刚总结过，稍后再试。"
	if r == "no_raw":
		return "暂无可总结内容。"
	if r == "below_threshold":
		return "内容还不多，先继续用一会儿再总结。"
	if r.is_empty():
		return "跳过总结。"
	return "跳过总结：" + r


func _friendly_error(err: String) -> String:
	var e := err.strip_edges()
	if e == "missing_api_key":
		return "DeepSeek 未配置（缺少 API Key）。请到【设置】填写后重试。"
	if e == "missing_endpoint":
		return "DeepSeek 未配置（缺少 Endpoint）。请到【设置】填写后重试。"
	if e == "missing_model":
		return "DeepSeek 未配置（缺少 Model）。请到【设置】填写后重试。"
	return e


func _find_pipeline() -> SummarizationPipeline:
	var p: Node = self
	while p != null:
		var n := p.get_node_or_null("SummarizationPipeline")
		if n != null and n is SummarizationPipeline:
			return n as SummarizationPipeline
		p = p.get_parent()
	return null


func _find_report_generator() -> ReportGenerator:
	var p: Node = self
	while p != null:
		var n := p.get_node_or_null("ReportGenerator")
		if n != null and n is ReportGenerator:
			return n as ReportGenerator
		p = p.get_parent()
	return null
