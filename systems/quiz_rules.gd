class_name QuizRules
extends RefCounted
## Field Check questions: which one to ask after a pile, and whether an answer is right.

const ANSWERED_FLAG_FORMAT := "quiz_done_%s"


static func is_answered(quiz_id: String) -> bool:
	return GameState.has_flag(ANSWERED_FLAG_FORMAT % quiz_id)


## The first unanswered question about any of these lessons, or {} when none is left.
static func pick(lesson_ids: Array) -> Dictionary:
	for quiz: Dictionary in Content.quizzes():
		if lesson_ids.has(quiz["lesson_id"]) and not is_answered(quiz["id"]):
			return quiz
	return {}


static func is_correct(quiz: Dictionary, choice: int) -> bool:
	return choice == int(quiz.get("answer", -1))
