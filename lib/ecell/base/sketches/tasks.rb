require 'ecell/elements/figure'
require 'ecell/base/designs/follower'
require 'ecell/base/designs/worker'
require 'ecell'

module ECell
  module Base
    module Sketches
      class TasksShape < ECell::Elements::Figure
        def on_started
          endpoint = ECell.sync(:distribution).distribution_input!(:tasks)
          initialize_line(:distribution_pull, mode: :connecting, endpoint: endpoint)
        end

        module Operations
          def work_10
            #de Send back time estimate, then do real work.
          end

          def work_9; end
          def work_8; end
          def work_7; end
          def work_6; end
          def work_5; end
          def work_4; end
          def work_3; end
          def work_2; end
          def work_1; end
        end
        include Operations
      end

      tasks_design = [
        {
          as: :tasks_figure,
          shape: TasksShape
        }
      ]

      Tasks = {
        designs: [
          ECell::Base::Designs::Follower,
          ECell::Base::Designs::Worker,
          tasks_design
        ],
        task_handler: :tasks_figure
      }
    end
  end
end

