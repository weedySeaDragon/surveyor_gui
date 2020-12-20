module SurveyorGui
  module Models
    module ResponseSetMethods

      DEPENDENCY_SHOW = 0
      DEPENDENCY_HIDE = 1

      def self.included(base)
        base.send :has_many, :responses, :dependent => :destroy
        base.send :attr_accessible, :survey, :responses_attributes, :user_id, :survey_id, :test_data if defined? ActiveModel::MassAssignmentSecurity
      end

      # determine whether a mandatory Question is missing a response.
      #  Only applicable if the question is not dependent on other questions,
      #  or if it is dependent, but has been triggered for inclusion by a previous answer.
      #
      def triggered_mandatory_missing

        qs = survey.sections.map(&:questions).flatten

        #ds = Dependency.all(:include => :dependency_conditions, :conditions => {:dependency_conditions => {:question_id => qs.map(&:id) || responses.map(&:question_id)}})
        ds = Dependency.includes(:dependency_conditions).where(:question_id => qs.map(&:id) || responses.map(&:question_id))

        triggered = qs - ds.select { |d| !d.is_met?(self) }.map(&:question)
        triggered_mandatory = triggered.select { |q| q.mandatory? }
        triggered_mandatory_completed = triggered.select { |q| q.mandatory? and is_answered?(q) }

        triggered_mandatory_missing = triggered_mandatory - triggered_mandatory_completed

        return triggered_mandatory_missing

      end

      # TODO: create a method to return the right css string (g_<id> or q_...)
      # @return [Hash] - a hash of dependent questions to show or hide
      def all_dependencies(question_ids = nil)
        arr = dependencies(question_ids).partition { |d| d.is_met?(self) }
        dependencies_to_show = arr[DEPENDENCY_SHOW].map { |d| d.question_group.present? ? "g_#{d.question_group_id}" : "q_#{d.question_id}" }
        dependencies_mandatory_to_show = arr[DEPENDENCY_SHOW].map { |d| d.question_group.present? ? "g_#{d.question_group_id}" : (d.question.is_mandatory? ? "q_#{d.question_id}" : nil)  }
        dependencies_to_hide = arr[DEPENDENCY_HIDE].map { |d| d.question_group.present? ? "g_#{d.question_group_id}" : "q_#{d.question_id}"  }
        { show: dependencies_to_show,
          show_mandatory: dependencies_mandatory_to_show,
          hide: dependencies_to_hide }
      end

      def correctness_hash
        { :questions => Survey.where(id: self.survey_id).includes(sections: :questions).first.sections.map(&:questions).flatten.compact.size,
          :responses => responses.to_a.compact.size,
          :correct => responses.find_all(&:correct?).compact.size
        }
      end

      def report_user_name
        user_name = nil
        fake_users = { '0' => 'Bob', '-1' => 'Kishore', '-2' => 'Tina', '-3' => 'Xiao', '-4' => 'Marshal', '-5' => 'Lana', '-6' => 'Demarius', '-7' => 'Taylor', '-8' => 'Cameron', '-9' => 'Clio' }
        if class_exists?('ResponseSetUser')
          user_name = ResponseSetUser.new(self.user_id).report_user_name
        end
        user_name || fake_users[self.user_id.to_s] || self.id
      end

      private

      def class_exists?(class_name)
        klass = Module.const_get(class_name)
        return klass.is_a?(Class)
      rescue NameError
        return false
      end
    end
  end
end
