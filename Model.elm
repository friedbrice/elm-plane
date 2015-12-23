module Model where
import Array
import Random exposing (int, generate, initialSeed, Generator, Seed)
import Time exposing (..)

type State = Play | Start | GameOver

type PillarKind = Top | Bottom

type alias Pillar =
  { x : Float
  , y : Float
  , height: Int
  , kind : PillarKind
  , passed : Bool
  }

type alias Constants =
  { backgroundScrollV : Float
  , foregroundScrollV : Float
  , playerX : Float
  , jumpSpeed : Float
  , gravity : Float
  , timeBetweenPillars : Float
  , pillarWidth : Int
  , minPillarHeight : Int
  , planeHeight : Int
  , planeWidth : Int
  , gapToPlaneRatio : Float
  , gapHeight : Int
  , epsilon : Float
  , randomizer : Generator Int
  }

type alias Game =
  { state : State
  , backgroundX : Float
  , y : Float
  , vy : Float
  , timeToPillar : Float
  , pillars : Array.Array Pillar
  , score : Int
  }

(gameWidth,gameHeight) = (480,480)

constants : Constants
constants =
  let
    planeHeight = 35
    gapToPlaneRatio = 3.5
    gapHeight = round ((toFloat planeHeight) * gapToPlaneRatio)
    minPillarHeight = round (gameHeight / 8)
  in
    { backgroundScrollV = 40
    , foregroundScrollV = 150
    , playerX = 100 - gameWidth / 2
    , jumpSpeed = 370.0
    , gravity = 1500.0
    , timeBetweenPillars = 1.6
    , pillarWidth = 30
    , minPillarHeight = minPillarHeight
    , planeHeight = planeHeight
    , planeWidth = 60
    , gapToPlaneRatio = gapToPlaneRatio
    , gapHeight = gapHeight
    , epsilon = 5
    , randomizer = Random.int minPillarHeight (gameHeight - minPillarHeight - gapHeight)
    }

-- MODEL
defaultGame : Game
defaultGame =
  { state = Start
  , backgroundX = 0
  , y = 0
  , vy = 0
  , timeToPillar = constants.timeBetweenPillars
  , pillars = Array.empty
  , score = 0
  }
