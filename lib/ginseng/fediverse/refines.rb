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

        def escape_status
          return Service.sanitize_status(self)
        end

        def sanitize_status
          return Service.sanitize_status(self)
        end

        alias escape_note escape_status

        alias escape_toot escape_status
      end
    end
  end
end
