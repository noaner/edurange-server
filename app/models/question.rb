
class Question < ActiveRecord::Base
  belongs_to :scenario
  has_many :answers, dependent: :destroy

  # Need to rewrite this securely, use find_by


  # def grade(student_answer, student_id)
  #   if self.answers.where("answer_text = '#{student_answer}'").first
  #     return
  #   end

  #   self.answer_text.split('&').each do |answer|
  #     answers_or = answer.split('|')

  #     answer = false
  #     correct = false
  #     answers_or.each do |answer_or|
  #       answer_or = answer_or.strip
  #       if self.answers.where("answer_text = '#{answer_or}'").first
  #         answer = true
  #       end
  #       if answer_or.eql?(student_answer)
  #         correct = true
  #       end
  #     end

  #     if correct and !answer
  #       answer = self.answers.new
  #       answer.student_id = student_id
  #       answer.answer_text = student_answer
  #       answer.correct = true
  #       answer.save!
  #       return 
  #     end

  #     if correct and answer
  #       return
  #     end

  #   end

  #   answer = self.answers.new
  #   answer.student_id = student_id
  #   answer.answer_text = student_answer
  #   answer.correct = false
  #   answer.save!
  # end
  
end
