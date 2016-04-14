class ScoringController < ApplicationController

  ## Insecure code right now, needs to be fixed

  # def instructor
  #   user = User.find(current_user.id)
  #   if !user.is_instructor?
  #     return
  #   end
  #   @scenario = Scenario.find(params[:scenario])
  # end

  # def student
  #   @scenario = Scenario.find(params[:scenario])
  #   @user = User.find(current_user.id)
  # end

  # def instructor_student
  #   user = User.find(current_user.id)
  #   if !user.is_instructor?
  #     return
  #   end

  #   @student = User.find(params[:user])
  #   @scenario = Scenario.find(params[:scenario])
  # end

  # def answer_question
  #   scenario = Scenario.find(params[:scenario])
  #   question = Question.find(params[:question])
  #   if question.kind == "StringMatch"
  #     question.grade(params[:answer_text], current_user.id)
  #   elsif question.kind == "Essay"
  #     answer = question.answers.new(
  #       answer_text: params[:answer_text],
  #       student_id: current_user.id
  #     ).save
  #   end
  #   redirect_to '/scoring/student/' + scenario.id.to_s
  # end

  # def answer_open_question

  #   @question = Question.find(params[:question])
  #   if params[:answer_area] == ''
  #     @question.answers.where("student_id = #{current_user.id}").destroy_all
  #     cnt = 0
  #   else
  #     if @question.answers.where("student_id = #{current_user.id}").first
  #       @answer = @question.answers.where("student_id = #{current_user.id}").first
  #     else
  #       @answer = @question.answers.new
  #     end
  #     @answer.answer_text = params[:answer_area]
  #     @answer.student_id = current_user.id
  #     @answer.save
  #     cnt = @question.scenario.questions.select{ |q| q.answers && q.answers.where("student_id = #{current_user.id}") }.size
  #   end

  #   total = @question.scenario.questions.select{ |q| q.answers }.size
  #   # PrivatePub.publish_to "/scenarios/#{@question.scenario.id}", answered: [current_user.id, "#{cnt}/#{total}"]

  #   respond_to do |format|
  #     format.js { render template: 'scoring/answer_open_question.js.erb', layout: false}
  #   end
  # end

  # def answer_dump
  #   @scenario = Scenario.find(params[:scenario])

  #   File.open(Rails.root + "data/scenario-#{@scenario.id}-#{@scenario.user.id}-answers.txt", 'w') do |f|
  #     f.write("Scenario: #{@scenario.name}\nInstructor: #{@scenario.user.name}\nDate: #{@scenario.created_at}\n\n")
  #     @scenario.players.each do |player|
  #       if player.user_id
  #         f.write(player.user.email + "\n\n")
  #         @scenario.questions.each do |question|
  #           f.write("  " + question.question_text + "\n\n")
  #           if answer = question.answers.where("student_id = #{player.user.id}").first
  #             f.write("    " + answer.answer_text + "\n\n")
  #           end
  #         end
  #       end
  #     end
  #   end

  #   send_file Rails.root + "data/scenario-#{@scenario.id}-#{@scenario.user.id}-answers.txt"
  # end

end
