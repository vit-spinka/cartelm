module Main exposing (..)

import Browser
import Html exposing (Html, div, h1, img, table, td, text, th, thead, tr)
import Html.Attributes exposing (src)



---- MODEL ----


type alias OneSub =
    { email : String
    , cartoon : String
    }


type alias Model =
    List OneSub


init : ( Model, Cmd Msg )
init =
    ( [ { email = "e1", cartoon = "c1" }, { email = "e2", cartoon = "c2" } ], Cmd.none )



---- UPDATE ----


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )



---- VIEW ----


viewOneSub : OneSub -> Html Msg
viewOneSub onesub =
    tr []
        [ td [] [ text onesub.email ]
        , td [] [ text onesub.cartoon ]
        ]


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Cartoon (Dilbert) subscription manager" ]
        , table []
            (thead []
                [ th [] [ text "Email" ]
                , th [] [ text "Cartoon" ]
                ]
                :: List.map viewOneSub model
            )
        ]



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = always Sub.none
        }
