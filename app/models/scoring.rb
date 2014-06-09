class Scoring
  def self.instance_scoring(instance)
    instance.provider_upload_scoring_url
    instance.provider_upload_scoring_page
  end

  def self.generate_scenario_urls(scenario)
    scenario.provider_scenario_upload_scoring_pages
    scenario.provider_scenario_upload_answers
  end

  def self.scenario_scoring(scenario)
    scenario.provider_scenario_write_to_scoring_pages
  end

end