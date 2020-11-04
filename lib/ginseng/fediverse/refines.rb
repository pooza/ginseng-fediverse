module Ginseng
  module Fediverse
    module Refines
      class ::String
        def to_hashtag
          return Service.create_tag(self)
        end

        def to_hashtag_base
          return Service.create_tag_base(self)
        end
      end
    end
  end
end
