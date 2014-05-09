Park Media
==========

## Utilities

### Park Media API [bin/park_media]

#### USAGE

    Usage: park_media [options]
            --park-media-host-address HOSTADDRESS
                                         The AdobeAnywhere server address.
                                          default:
            --park-media-host-port PORT  The port on the Park Media server to connect to.
                                          default:
            --park-media-username USERNAME
                                         The username to login with. This will be ignored if cookie contents is set and the force login parameter is false.
                                          default:
            --park-media-password PASSWORD
                                         The password to login with. This will be ignored if cookie contents is set and the force login parameter is false.
                                          default:
            --force-login                Forces a new cookie even if cookie information is present.
            --method-name METHODNAME
            --method-arguments JSON
            --pretty-print
            --cookie-contents CONTENTS   Sets the cookie contents.
            --cookie-file-name FILENAME  Sets the cookie contents from the contents of a file.
            --set-cookie-env             Saves cookie contents to an environmental variable named PARK_MEDIA_API_SESSION_COOKIE
            --set-cookie-file FILENAME   Saves cookie contents to a file.
            --log-to FILENAME            Log file location.
                                          default: STDERR
            --log-level LEVEL            Logging level. Available Options: debug, info, warn, error, fatal
                                          default: warn
            --[no-]options-file [FILENAME]
                                         Path to a file which contains default command line arguments.
                                          default: ~/.options/park_media
        -h, --help                       Show this message.

#### EXAMPLES

##### Asset Create

    park_media --method-name asset_create --method-arguments '{"assetName":"Test", "assetType":"Audio","assetFileExtension":"mp3", "assetFileUrl":"http://someserver/somefile.mp3","metadata/someFieldName":"SomeFieldValue"}'

##### Asset Get

    park_media --method-name asset --method-arguments '{"asset_id":1234}'

##### Asset Edit

    park_media --method-name asset_edit --method-arguments '{"asset_id":1234, "assetName":"new name", "asset-metadata" : { "artist" : "some artist", "track" : "some track" } }'

#### Options File

##### Default Location
    ~/.options/park_media

##### Example Content

    --park-media-server-address=eval.parkmedia.tv
    --park-media-username=username
    --park-media-password=password
    --log-level=debug
    --pretty-print