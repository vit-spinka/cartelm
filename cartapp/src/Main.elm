module Main exposing (..)

import Browser
import Html exposing (Html, button, div, h1, img, input, table, td, text, th, thead, tr)
import Html.Attributes exposing (placeholder, required, src, style, type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as JD exposing (Decoder, field, list, string, succeed)
import Json.Encode as JE exposing (Value, object, string)


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
    { sublist : List OneSub
    , addingEnabled : Bool
    , addingEmail : String
    , addingCartoon : String
    , addingError : Maybe String
    }


initialModel : Model
initialModel =
    { sublist = [], addingEnabled = False, addingEmail = "", addingCartoon = "", addingError = Nothing }


init : () -> ( Model, Cmd Msg )
init () =
    ( initialModel, fetchGetAllSubs )



---- UPDATE ----


cartDecoder : Decoder OneSub
cartDecoder =
    JD.map3 OneSub
        (field "subscriptionId" JD.string)
        (field "cartoon" JD.string)
        (field "email" JD.string)


cartListDecoder : Decoder (List OneSub)
cartListDecoder =
    list cartDecoder


encodeAdd : Model -> Value
encodeAdd model =
    object [ ( "email", JE.string model.addingEmail ), ( "cartoon", JE.string model.addingCartoon ) ]


type Msg
    = LoadSubscriptions (Result Http.Error (List OneSub))
    | ToggleAdding
    | UpdateAddedSub String
    | UpdateAddedCartoon String
    | SaveNewSub
    | SaveNewSubResult (Result Http.Error String)
    | DeleteSub String
    | DeleteSubResult (Result Http.Error String)


fetchGetAllSubs : Cmd Msg
fetchGetAllSubs =
    Http.get { url = baseUrl ++ "/test/subscription", expect = Http.expectJson LoadSubscriptions cartListDecoder }


saveNewSub : Model -> Cmd Msg
saveNewSub model =
    Http.post { url = baseUrl ++ "/test/subscription", body = Http.jsonBody (encodeAdd model), expect = Http.expectString SaveNewSubResult }


deleteSub : String -> Cmd Msg
deleteSub id =
    Http.request { method = "DELETE", url = baseUrl ++ "/test/subscription/" ++ id, expect = Http.expectString DeleteSubResult, headers = [], body = Http.emptyBody, timeout = Nothing, tracker = Nothing }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadSubscriptions (Ok sublist) ->
            ( { model | sublist = sublist }, Cmd.none )

        LoadSubscriptions (Err _) ->
            ( model, Cmd.none )

        ToggleAdding ->
            ( { model | addingEnabled = not model.addingEnabled }, Cmd.none )

        UpdateAddedSub email ->
            ( { model | addingEmail = email }, Cmd.none )

        UpdateAddedCartoon cart ->
            ( { model | addingCartoon = cart }, Cmd.none )

        SaveNewSub ->
            ( model, saveNewSub model )

        SaveNewSubResult (Ok _) ->
            ( { model | addingEnabled = False, addingEmail = "", addingCartoon = "", addingError = Nothing }, fetchGetAllSubs )

        SaveNewSubResult (Err _) ->
            ( { model | addingEnabled = True, addingError = Just "Save failed." }, Cmd.none )

        DeleteSub id ->
            ( model, deleteSub id )

        DeleteSubResult (Ok _) ->
            ( model, fetchGetAllSubs )

        DeleteSubResult (Err _) ->
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
        , td [] [ button [ onClick (DeleteSub onesub.subscriptionId) ] [ text "Delete" ] ]
        ]


toggleAddButton : Model -> Html Msg
toggleAddButton model =
    tr [] [ td [] [ button [ onClick ToggleAdding ] [ text "Add New Item" ] ] ]


viewError : Maybe String -> Html Msg
viewError addingError =
    case addingError of
        Just err ->
            text err

        Nothing ->
            text ""


addDiv : Model -> Html Msg
addDiv model =
    case model.addingEnabled of
        True ->
            tr []
                [ td [] [ input [ type_ "text", placeholder "Subscriber email", value model.addingEmail, onInput UpdateAddedSub ] [] ]
                , td [] [ input [ type_ "text", placeholder "Cartoon to send", value model.addingCartoon, onInput UpdateAddedCartoon ] [] ]
                , td [] [ button [ onClick SaveNewSub ] [ text "Save New Item" ] ]
                , td [ style "color" "red" ] [ viewError model.addingError ]
                ]

        False ->
            text ""


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
                ++ [ toggleAddButton model ]
                ++ [ addDiv model ]
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
