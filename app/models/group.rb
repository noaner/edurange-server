class Group < ActiveRecord::Base
  belongs_to :scenario
  has_many :instance_groups, dependent: :destroy
  has_many :instances, through: :instance_groups
  has_many :players, dependent: :destroy
  has_one :user, through: :scenario

  validates :name, presence: true, uniqueness: { scope: :scenario, message: "Name taken" }
  validate :instances_stopped

  after_save :update_scenario_modified
  before_destroy :instances_stopped
  after_destroy :update_scenario_modified

  def update_scenario_modified
    if self.scenario.modifiable?
      return self.scenario.update_attribute(:modified, true)
    end
  end

  def administrative_access_to
    instances = self.instance_groups.select {|instance_group| instance_group.administrator }.map {|instance_group| instance_group.instance}
  end

  def instances_stopped
    self.instance_groups.each do |instance_group|
      if not instance_group.instance.stopped?
        errors.add(:running, "instances with access must be stopped before modificaton of group")
        return false
      end
    end
    true
  end

  def instances_stopped?
    self.instance_groups.each do |instance_group|
      if not instance_group.instance.stopped?
        errors.add(:running, 'instances with access must be stopped to modify group')
        return false
      end
    end
    true
  end

  def user_access_to
    instances = self.instance_groups.select {|instance_group| !instance_group.administrator }.map {|instance_group| instance_group.instance}
  end

  def student_group_add(student_group_name)
    if not self.instances_stopped?
      return []
    end

    players = []
    user = User.find(self.scenario.user.id)
    if not student_group = user.student_groups.find_by_name(student_group_name)
      errors.add(:name, "student group not found")
      return
    end
    student_group.student_group_users.each do |student_group_user|
      if not self.players.where("user_id = #{student_group_user.user_id} AND student_group_id = #{student_group.id}").first

        cnt = 1
        login = "#{student_group_user.user.name.filename_safe}"
        while self.players.find_by_login(login)
          cnt += 1
          login = login += cnt.to_s
        end

        player = self.players.new(
          login: login,
          password: SecureRandom.base64[0..8],
          user_id: student_group_user.user.id,
          student_group_id: student_group_user.student_group.id
        )
        player.save
        players.push(player)
      end
    end
    self.update_scenario_modified
    players
  end

  def student_group_remove(student_group_name)
    if not self.instances_stopped?
      return []
    end

    players = []
    user = User.find(self.scenario.user.id)
    if not student_group = user.student_groups.find_by_name(student_group_name)
      errors.add(:name, "student group not found")
      return
    end
    student_group.student_group_users.each do |student_group_user|
      if player = self.players.find_by_user_id(student_group_user.user.id)
        players.push(player)
        player.delete
      end
    end
    self.update_scenario_modified
    players
  end

  def find_player_by_student_id(student_id)
    self.players.each do |player|
      if player.user
        return player if player.user.id == student_id
      end
    end
    nil
  end

  def update_instructions(instructions)
    self.update_attribute(:instructions, instructions)
    self.update_scenario_modified
  end

end
