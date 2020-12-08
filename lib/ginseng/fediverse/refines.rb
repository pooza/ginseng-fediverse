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

        def escape_toot
          return sub(/[@#]/, '\\0 ')
        end

        alias escape_note escape_toot
      end
    end
  end
end
