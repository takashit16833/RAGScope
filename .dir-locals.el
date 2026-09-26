((nil . ((my/project-commands
          . (("Make check"
              :command "make check-app"
              :description "RAGScopeアプリケーションの品質検査をすべて実行する")
             ("Make format"
              :command "make format-app"
              :description "HaskellソースをFourmoluで整形する")
             ("Make format check"
              :command "make format-check-app"
              :description "Haskellソースの整形状態を確認する")
             ("Cabal build"
              :command "cd ragscope-app && cabal build all"
              :description "RAGScopeアプリケーションをビルドする")
             ("Cabal test"
              :command "cd ragscope-app && cabal test all"
              :description "RAGScopeアプリケーションのテストを実行する")
             ("Cabal run"
              :command "cd ragscope-app && cabal run ragscope"
              :description "RAGScope executableを実行する"))))))
