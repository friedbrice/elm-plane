import Color exposing (..)
import Graphics.Collage exposing (..)
import Graphics.Element exposing (..)
import Keyboard
import Time exposing (..)
import Window
import Debug exposing (watch)
import Array
import Text
import List
import Random exposing (int, generate, initialSeed, Generator, Seed)
import Types exposing (..)
import Utils

(gameWidth,gameHeight) = (800,480)

constants : Constants
constants =
  let
    planeHeight = 35
    gapToPlaneRatio = 3.5
    gapHeight = round ((toFloat planeHeight) * gapToPlaneRatio)
    minPillarHeight = round (gameHeight / 8)
  in
    {
    backgroundScrollV = 40
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
  , foregroundX = 0
  , backgroundX = 0
  , y = 0
  , vy = 0
  , timeToPillar = constants.timeBetweenPillars
  , pillars = Array.empty
  , score = 0
  }

-- UPDATE
update : Input -> Game -> Game
update input game =
  -- let
  --   score = Debug.watch "score" game.score
  -- in
    case input of
      TimeDelta delta ->
        --TODO: can I pass the delta somehow as well?
        game
          |> updatePlayerY delta
          |> updateBackground delta
          |> applyPhysics delta
          |> checkFailState delta
          |> updatePillars delta
          |> updateScore delta
      Space space ->
        game
          |> transitionState space
          |> updatePlayerVelocity space

--Time updates
updatePlayerY : TimeUpdate
updatePlayerY delta game =
  {game | y <-
    if | game.state == Start -> game.y + (sin (game.backgroundX / 10))
       | game.state == Play || (game.state == GameOver && game.y > -gameHeight/2)-> game.y + game.vy * (snd delta)
       | otherwise -> game.y
  }

checkFailState : TimeUpdate
checkFailState delta game =
  let
    playerOffScreen =
      game.y <= -gameHeight/2
    collisionPillars =
      Array.filter (\p -> Utils.isColliding constants game p) game.pillars |>
      Array.length
    playerCollidedWithPillar = collisionPillars > 0
  in
    {game | state <-
      if game.state == Play && (playerOffScreen || playerCollidedWithPillar) then GameOver
      else game.state
    }

updateBackground : TimeUpdate
updateBackground delta game =
  {game | backgroundX <-
    if | game.backgroundX > gameWidth -> 0
       | game.state == GameOver -> game.backgroundX
       | otherwise -> game.backgroundX + (snd delta) * constants.backgroundScrollV
  }

applyPhysics : TimeUpdate
applyPhysics delta game =
  {game | vy <-
    if | game.state == GameOver && game.y <= -gameHeight/2 -> 0
       | otherwise -> game.vy - (snd delta) * constants.gravity
  }

updatePillars : TimeUpdate
updatePillars delta game =
  let
    timeToPillar =
      if | game.timeToPillar <= 0 -> constants.timeBetweenPillars
         | game.state == Play -> game.timeToPillar - (snd delta)
         | otherwise -> game.timeToPillar
    shouldAddPillar = timeToPillar == constants.timeBetweenPillars && game.state == Play
    updatedPillars =
      Array.map (\p -> {p | x <- p.x - constants.foregroundScrollV * (snd delta)}) game.pillars |>
      Array.filter (\p -> p.x > -(gameWidth/2))
    pillars =
      if | game.state /= Play -> game.pillars
         | shouldAddPillar -> Array.append  (generatePillars (fst delta) game) updatedPillars
         | otherwise -> updatedPillars

  in
    {game | timeToPillar <- timeToPillar
          , pillars <- pillars
    }

generatePillars : Time -> Game -> Array.Array Pillar
generatePillars time game =
  let
    bottomHeight =
      fst <| generate constants.randomizer <| initialSeed <| round <| inMilliseconds time
    topHeight =
      gameHeight - bottomHeight - constants.gapHeight
  in
    Array.fromList <|
    [
      { x = gameWidth/2 + (toFloat constants.pillarWidth)
      , y = (toFloat bottomHeight/2) - (gameHeight/2)
      , height = bottomHeight
      , kind = Bottom
      , passed = False
      }
      ,
      { x = gameWidth/2 + (toFloat constants.pillarWidth)
      , y = (gameHeight/2 - (toFloat topHeight/2))
      , height = topHeight
      , kind = Top
      , passed = False
      }
    ]

updateScore : TimeUpdate
updateScore delta game =
  let
    length =
      Array.length <| Array.filter (\p -> not p.passed && p.x < constants.playerX) game.pillars
    pillars =
      if (length > 0) then
        Array.map (\p -> if not p.passed && p.x < constants.playerX then {p | passed <- True} else p) game.pillars
      else
        game.pillars
  in
    {game |
      pillars <- pillars
    , score <- if length > 0 then game.score + 1 else game.score
    }

--Input updates
transitionState : KeyUpdate
transitionState space game =
  if game.state == GameOver && game.y <= -gameHeight/2 && space then defaultGame --Reset
  else
    {game |
      state <-
        if | game.state == Start && space -> Play
           | otherwise -> game.state
    }

updatePlayerVelocity : KeyUpdate
updatePlayerVelocity space game =
  {game | vy <-
    if game.state == Play && space then constants.jumpSpeed
    else game.vy
  }

-- VIEW
pillarToForm : Pillar -> Form
pillarToForm p =
  let
    imageName =
      if p.kind == Top then "/images/topRock.png"
      else "/images/bottomRock.png"
  in
    image constants.pillarWidth p.height imageName |>
    toForm |>
    move (p.x, p.y)

view : (Int,Int) -> Game -> Element
view (w,h) game =
  let
    gameOverAlpha =
      if game.state == GameOver then 1 else 0
    getReadyAlpha =
      if game.state == Start then 1 else 0
    pillarForms =
      Array.map pillarToForm game.pillars
    formList =
      [
         toForm (image gameWidth gameHeight "/images/background.png")
           |> move (-game.backgroundX, 0)
      ,  toForm (image gameWidth gameHeight "/images/background.png")
           |> move (gameWidth - game.backgroundX, 0)
      ,  toForm (image constants.planeWidth constants.planeHeight "/images/plane.gif")
          |> move (constants.playerX, game.y)
      ,  toForm (image 400 70 "/images/textGameOver.png")
          |> alpha gameOverAlpha
      ,  toForm (image 400 70 "/images/textGetReady.png")
              |> alpha getReadyAlpha
      ]
    textLineStyle = (solid black)
    score =
        Text.fromString (toString game.score)
        |> (Text.height 50)
        |> Text.color yellow
        |> Text.bold
        |> outlinedText textLineStyle
        |> move (0, gameHeight/2 - 70)


    fullFormList =
      List.append formList
      <| Array.toList
      <| Array.push score pillarForms

  in
    container w h middle <|
    collage gameWidth gameHeight <|
    fullFormList

-- SIGNALS
main =
  Signal.map2 view Window.dimensions gameState


gameState : Signal Game
gameState =
    Signal.foldp update defaultGame input

delta = timestamp <|
      Signal.map inSeconds (fps 45)

input : Signal Input
input =
        Signal.mergeMany [Signal.map TimeDelta delta, Signal.map Space Keyboard.space]
