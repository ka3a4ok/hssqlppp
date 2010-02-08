Copyright 2010 Jake Wheat

Gather together the examples from the extension modules and convert to regular test code

> module Database.HsSqlPpp.Examples.Extensions.ExtensionTests
>     (extensionTests) where
>
> import Test.HUnit
> import Test.Framework
> import Test.Framework.Providers.HUnit
> import Control.Monad
> --import Debug.Trace
>
> import Database.HsSqlPpp.Annotation
> import Database.HsSqlPpp.PrettyPrinter
> import Database.HsSqlPpp.Utils.Utils
>
> import Database.HsSqlPpp.Examples.Extensions.ExtensionsUtils
> import Database.HsSqlPpp.Examples.Extensions.CreateVarSimple
> import Database.HsSqlPpp.Examples.Extensions.CreateVar
> import Database.HsSqlPpp.Examples.Extensions.TransitionConstraints
> --import Database.HsSqlPpp.Examples.Extensions.ExtendedConstraints
> import Database.HsSqlPpp.Examples.Extensions.ExtendedConstraintTests

> testData :: [ExtensionTest]
> testData = transitionConstraintExamples ++
>            extendedConstraintExamples ++
>            [createVarSimpleExample
>            ,createVarExample
>            ]

ddl 'triggers' -> reject, transform, or supplement a ddl statement
addreadonlytriggers
addnotifytriggers
constraints
zeroonetuple
transitionconstraints
default not null
modules
'_mr' table definitions and initialization data / relation constants
multiple updates
out of order definitions (after missing catalog elements are done)
simplified catalog

chaos: leftovers already written,
       turn sequence progression
       action valid tables
       ai
       what else?
       revlar types
       check only updates are in action_ functions

idea for attributes:
select attribute('type','readonly');
create table readonly_table ...

> extensionTests :: Test.Framework.Test
> extensionTests = testGroup "extensionTests" $ map testExtension testData

> testExtension :: ExtensionTest -> Test.Framework.Test
> testExtension (ExtensionTest nm tr sast ts) =
>   testCase nm $ do
>     let ts' = stripAnnotations ts
>         es' = stripAnnotations $ tr sast
>     when (ts' /= es') $ putStrLn $ printSql ts' ++ "\n----\n" ++ printSql es' ++ "\n====\n" ++
>                 ppExpr ts' ++ "\n----\n" ++ ppExpr es'
>     assertEqual "" ts' es'