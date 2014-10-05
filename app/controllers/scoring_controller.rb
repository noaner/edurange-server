class ScoringController < ApplicationController

  def instructor
    user = User.find(current_user.id)
    if !user.is_instructor?
      return
    end
    
    @scenario = Scenario.find(params[:scenario])
  end

  def student
    @scenario = Scenario.find(params[:scenario])
  end

  def instructor_student
    user = User.find(current_user.id)
    if !user.is_instructor?
      return
    end

    @student = User.find(params[:user])
    @scenario = Scenario.find(params[:scenario])
  end

  def answer_question
    scenario = Scenario.find(params[:scenario])
    question = Question.find(params[:question])
    if question.kind == "StringMatch"
      question.grade(params[:answer_text], current_user.id)
    elsif question.kind == "Essay"
      answer = question.answers.new(
        answer_text: params[:answer_text],
        student_id: current_user.id
      ).save
    end
    redirect_to '/scoring/student/' + scenario.id.to_s
  end

  def answer_open_question

    @question = Question.find(params[:question])
    if @question.answers.first
      @answer = @question.answers.first
    else
      @answer = @question.answers.new
    end

    @answer.answer_text = params[:answer_area]
    @answer.save

    respond_to do |format|
      format.js { render template: 'scoring/answer_open_question.js.erb', layout: false}
    end
  end

end
