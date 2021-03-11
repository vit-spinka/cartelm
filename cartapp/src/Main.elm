module Main exposing (..)

import Browser
import Html exposing (Html, div, h1, img, table, td, text, th, thead, tr)
import Html.Attributes exposing (required, src)
import Http
import Json.Decode as JD exposing (Decoder, field, list, string, succeed)


baseUrl : String
baseUrl =
    "https://64dz3dvrfl.execute-api.us-west-2.amazonaws.com"



-- import Json.Decode.Pipeline exposing (required)
---- MODEL ----


type alias OneSub =
    { subscriptionId : String
    , cartoon : String
    , email : String
    }


type alias Model =
    { sublist : List OneSub }


initialModel : Model
initialModel =
    { sublist = [] }


init : () -> ( Model, Cmd Msg )
init () =
    ( initialModel, fetchGetAllSubs )



---- UPDATE ----


cartDecoder : Decoder OneSub
cartDecoder =
    JD.map3 OneSub
        (field "subscriptionId" string)
        (field "cartoon" string)
        (field "email" string)


cartListDecoder : Decoder (List OneSub)
cartListDecoder =
    list cartDecoder


type Msg
    = LoadSubscriptions (Result Http.Error (List OneSub))


fetchGetAllSubs : Cmd Msg
fetchGetAllSubs =
    Http.get { url = baseUrl ++ "/test/subscription", expect = Http.expectJson LoadSubscriptions cartListDecoder }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadSubscriptions (Ok sublist) ->
            ( { model | sublist = sublist }, Cmd.none )

        LoadSubscriptions (Err _) ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



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
                :: List.map viewOneSub model.sublist
            )
        ]



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = init
        , update = update
        , subscriptions = always Sub.none
        }
