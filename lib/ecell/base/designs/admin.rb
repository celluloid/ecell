require 'ecell/base/shapes/logging'
require 'ecell/base/shapes/awareness'
require 'ecell/base/shapes/management'
require 'ecell/extensions'

module ECell
  module Base
    module Designs
      Admin = [
        {
          as: :logging,
          shape: ECell::Base::Shapes::Logging,
          faces: [:document],
          strokes: {logging_push: {mode: :connecting}}
        },
        {
          as: :awareness,
          faces: [:announce],
          shape: ECell::Base::Shapes::Awareness,
          strokes: {awareness_publish: {mode: :connecting}}
        },
        {
          as: :system,
          faces: [:administrate],
          shape: ECell::Base::Shapes::Management,
          init: {management_reply: {mode: :binding}}
        }
      ]
    end
  end
end

