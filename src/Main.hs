import qualified Graphics.Svg as SVG

import Data.Text
import qualified Data.Configurator as C

import Data.Monoid

import Options.Applicative

import Render
import GCode
                                                 
data Options = Options { _svgfile :: String
                       , _cfgfile :: Maybe String
                       , _outfile :: Maybe String
                       , _dpi     :: Int
                       }                
                
options :: Parser Options
options = Options
  <$> argument str
      ( metavar "SVGFILE"
     <> help "The SVG file to be converted" )
  <*> (optional $ strOption
      ( long "flavor"
     <> short 'f' 
     <> metavar "CONFIGFILE"     
     <> help "Configuration of G-Code flavor" ))
  <*> (optional $ strOption
      ( long "output"
     <> short 'o'
     <> metavar "OUTPUTFILE"     
     <> help "The output G-Code file (default is standard output)" ))
  <*> (option auto
      ( long "dpi"
     <> value 72
     <> short 'd'
     <> metavar "DPI"     
     <> help "Density of the SVG file (default is 72 DPI)" ))

runWithOptions :: Options -> IO ()
runWithOptions (Options svgFile mbCfg mbOut dpi) =
    do 
        mbDoc <- SVG.loadSvgFile svgFile
        flavor <- maybe (return defaultFlavor) readFlavor mbCfg
        case mbDoc of
            (Just doc) -> writer (toString flavor dpi $ renderDoc dpi doc)
            Nothing    -> putStrLn "juicy-gcode: error during opening the SVG file"
    where
        writer = maybe putStrLn (\fn -> writeFile fn) mbOut
    
toLines :: Text -> String    
toLines t = unpack $ replace (pack ";") (pack "\n") t    
    
readFlavor :: FilePath -> IO GCodeFlavor
readFlavor cfgFile = do
  cfg          <- C.load [C.Required cfgFile]
  begin        <- C.require cfg (pack "gcode.begin")
  end          <- C.require cfg (pack "gcode.end")
  toolon       <- C.require cfg (pack "gcode.toolon")
  tooloff      <- C.require cfg (pack "gcode.tooloff")
  return $ GCodeFlavor (toLines begin) (toLines end) (toLines toolon) (toLines tooloff)
  
main :: IO ()
main = execParser opts >>= runWithOptions
  where
    opts = info (helper <*> options)
      ( fullDesc
     <> progDesc "Convert SVGFILE to G-Code" 
     <> header "juicy-gcode - The SVG to G-Code converter" )                
     