module Ginseng
  module Fediverse
    class ParserTest < TestCase
      def setup
        @parser = Parser.new
      end

      def test_text
        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン'
        assert_equal('ローリン♪ローリン♪ココロにズッキュン', @parser.text)
        assert_equal('ローリン♪ローリン♪ココロにズッキュン', @parser.to_s)
      end

      def test_body
        @parser.text = "ローリン♪ローリン♪\nココロにズッキュン\n\n#precure_fun #シュビドゥビ"
        assert_equal("ローリン♪ローリン♪\nココロにズッキュン", @parser.body)

        @parser.text = '<p>スマイルプリキュア<br /><a href=\"https://st.mstdn.b-shock.org/tags/mulukhiya\" class=\"mention hashtag\" rel=\"tag\">#<span>mulukhiya</span></a> <a href=\"https://st.mstdn.b-shock.org/tags/Example\" class=\"mention hashtag\" rel=\"tag\">#<span>Example</span></a> <a href=\"https://st.mstdn.b-shock.org/tags/%E3%82%B9%E3%83%9E%E3%82%A4%E3%83%AB%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2\" class=\"mention hashtag\" rel=\"tag\">#<span>スマイルプリキュア</span></a> <a href=\"https://st.mstdn.b-shock.org/tags/precure_fun\" class=\"mention hashtag\" rel=\"tag\">#<span>precure_fun</span></a></p>'
        assert_equal('スマイルプリキュア', @parser.body)
      end

      def test_footer
        @parser.text = "ローリン♪ローリン♪\nココロにズッキュン\n\n#precure_fun #シュビドゥビ"
        assert_equal('#precure_fun #シュビドゥビ', @parser.footer)

        @parser.text = '<p>スマイルプリキュア<br /><a href=\"https://st.mstdn.b-shock.org/tags/mulukhiya\" class=\"mention hashtag\" rel=\"tag\">#<span>mulukhiya</span></a> <a href=\"https://st.mstdn.b-shock.org/tags/Example\" class=\"mention hashtag\" rel=\"tag\">#<span>Example</span></a> <a href=\"https://st.mstdn.b-shock.org/tags/%E3%82%B9%E3%83%9E%E3%82%A4%E3%83%AB%E3%83%97%E3%83%AA%E3%82%AD%E3%83%A5%E3%82%A2\" class=\"mention hashtag\" rel=\"tag\">#<span>スマイルプリキュア</span></a> <a href=\"https://st.mstdn.b-shock.org/tags/precure_fun\" class=\"mention hashtag\" rel=\"tag\">#<span>precure_fun</span></a></p>'
        assert_equal('#mulukhiya #Example #スマイルプリキュア #precure_fun', @parser.footer)
      end

      def test_exec
        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン'
        assert_nil(@parser.exec)
        assert_nil(@parser.command_name)
        assert_false(@parser.command?)

        @parser.text = "command: command1\nfoo: bar"
        assert_equal({'command' => 'command1', 'foo' => 'bar'}, @parser.exec)
        assert_equal('command1', @parser.command_name)
        assert_predicate(@parser, :command?)

        @parser.text = '{"command": "command2", "bar": "buz"}'
        assert_equal({'command' => 'command2', 'bar' => 'buz'}, @parser.exec)
        assert_equal('command2', @parser.command_name)
        assert_predicate(@parser, :command?)
      end

      def test_hashtags
        @parser.text = 'pooza@b-shock.org'
        assert_equal(@parser.hashtags, Set[])

        @parser.text = '#aaa #bbbb @pooza @pooza@precure.ml よろです。'
        assert_equal(@parser.hashtags, Set['aaa', 'bbbb'])
      end

      def test_to_sanitized
        @parser.text = '<p>hoge<br>hoge</p><p>hoge<br>hoge</p>'
        assert_equal("hoge\nhoge\n\nhoge\nhoge", @parser.to_sanitized)

        @parser.text = %(このインスタンスがめいすきーのフォークであることを意識して、以下のような調整を行いました。<br>\n<br>\n・リポジトリのリンクを以下のものに修正<br>\nhttps://github.com/pooza/meisskey/tree/mei-m544.pooza<br>\n<br>\n・独自のバージョン番号<br>\n末尾に "-reco" 追加<br>)
        assert_equal("このインスタンスがめいすきーのフォークであることを意識して、以下のような調整を行いました。\n\n・リポジトリのリンクを以下のものに修正\nhttps://github.com/pooza/meisskey/tree/mei-m544.pooza\n\n・独自のバージョン番号\n末尾に \"-reco\" 追加", @parser.to_sanitized)
      end

      def test_accts
        @parser.text = '#hoge'
        assert_empty(@parser.accts.to_a)

        @parser.text = '@pooza @pooza@precure.ml よろです。 pooza@b-shock.org'
        @parser.accts do |acct|
          assert_kind_of(Acct, acct)
          assert_predicate(acct, :valid?)
        end
        assert_equal(['@pooza', '@pooza@precure.ml'], @parser.accts.map(&:to_s))
      end
    end
  end
end
