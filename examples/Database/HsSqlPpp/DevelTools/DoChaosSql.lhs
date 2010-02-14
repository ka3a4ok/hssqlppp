Copyright 2010 Jake Wheat

Convert the Chaos 2010 example sql to html, and do some stuff with
hssqlppp to it and show the results.

> {-# LANGUAGE ScopedTypeVariables #-}
> module Database.HsSqlPpp.DevelTools.DoChaosSql
>     (doChaosSql) where
>
> import System.FilePath.Find
> import System.FilePath
> import Control.Monad.Error
>
> import Database.HsSqlPpp.DevelTools.PandocUtils
> import Database.HsSqlPpp.Examples.AnnotateSource2

> doChaosSql :: (PandocType
>                -> String
>                -> Input
>                -> String
>                -> IO ())
>            -> IO ()
> doChaosSql pf = do
>   -- create html versions of original source
>   sourceFiles >>= mapM_ convFile
>   -- do annotated source files
>   new <- liftIO (annotateSource2 chaosSourceFiles)
>   forM_ new (\(f,c) -> pf Txt (snd (splitFileName f) ++ " transformed")
>                           (Str c) (f ++ ".tr.html"))
>   return ()
>   where
>     sourceFiles = do
>       find always sourceFileP "testfiles/chaos2010sql/"
>     sourceFileP = extension ==? ".sql" ||? extension ==? ".txt"
>     convFile f = do
>       pf (case takeExtension f of
>             ".txt" -> Txt
>             ".sql" -> Sql
>             _ -> error $ "unrecognised extension in dochaosql" ++ f)
>          (snd $ splitFileName f)
>          (File f)
>          (f ++ ".html")

> chaosSourceFiles :: [String]
> chaosSourceFiles =
>         ["testfiles/chaos2010sql/chaos/server/Metadata.sql"
>         ,"testfiles/chaos2010sql/chaos/server/PiecePrototypes.sql"
>         ,"testfiles/chaos2010sql/chaos/server/Spells.sql"
>         ,"testfiles/chaos2010sql/chaos/server/GlobalData.sql"
>         ,"testfiles/chaos2010sql/chaos/server/Wizards.sql"
>         ,"testfiles/chaos2010sql/chaos/server/Pieces.sql"
>         ,"testfiles/chaos2010sql/chaos/server/TurnSequence.sql"
>         ,"testfiles/chaos2010sql/chaos/server/ActionTestSupport.sql"
>         ,"testfiles/chaos2010sql/chaos/server/SquaresValid.sql"
>         ,"testfiles/chaos2010sql/chaos/server/Actions.sql"
>         ,"testfiles/chaos2010sql/chaos/server/ActionHistory.sql"
>         ,"testfiles/chaos2010sql/chaos/server/NewGame.sql"
>         ,"testfiles/chaos2010sql/chaos/server/AI.sql"
>         ,"testfiles/chaos2010sql/chaos/client/WindowManagement.sql"
>         ,"testfiles/chaos2010sql/chaos/client/Sprites.sql"
>         ,"testfiles/chaos2010sql/chaos/client/WizardDisplayInfo.sql"
>         ,"testfiles/chaos2010sql/chaos/client/BoardWidget.sql"
>         ,"testfiles/chaos2010sql/chaos/client/SpellBookWidget.sql"
>         ,"testfiles/chaos2010sql/chaos/client/NewGameWidget.sql"
>         ,"testfiles/chaos2010sql/chaos/client/ClientActions.sql"
>         ,"testfiles/chaos2010sql/chaos/client/ClientNewGame.sql"]


TODO:

use the new annotate, then we can present the original pristine
source, and the source that has been scribbled all over by hsssqlppp.

add a separate page to summarize the resulant catalog, use the modules
to split this into sections. When the export lists are done, use this
to divide each section into public, private.

add a separate page to list the type errors with links to the source
where they occur (both the original and mangled source)
