class ScoringController < ApplicationController

  def instructor
    @scenario = Scenario.find(params[:scenario])
  end

  def student
    @scenario = Scenario.find(params[:scenario])
  end

  def answer_question
    scenario = Scenario.find(params[:scenario])
    question = Question.find(params[:question])
    question.grade(params[:answer_text], current_user.id)
    redirect_to '/scoring/student/' + scenario.id.to_s
  end

end
