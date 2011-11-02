(:
Copyright 2011 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)

xquery version "1.0-ml";

module namespace common="http://marklogic.com/corona/common";
import module namespace json="http://marklogic.com/json" at "json.xqy";
import module namespace dateparser="http://marklogic.com/dateparser" at "date-parser.xqy";
import module namespace config="http://marklogic.com/corona/index-config" at "index-config.xqy";
import module namespace store="http://marklogic.com/corona/store" at "store.xqy";

declare namespace corona="http://marklogic.com/corona";
declare namespace search="http://marklogic.com/appservices/search";

declare default function namespace "http://www.w3.org/2005/xpath-functions";


declare function common:validateOutputFormat(
    $outputFormat as xs:string
) as xs:boolean
{
    $outputFormat = ("json", "xml")
};

declare function common:error(
    $exceptionCode as xs:string,
    $message as xs:string,
    $outputFormat as xs:string
)
{
    let $isA400 := (
        "corona:DUPLICATE-INDEX-NAME",
        "corona:DUPLICATE-PLACE-ITEM",
        "corona:REQUIRES-BULK-DELETE"
    )
    let $isA500 := (
        "corona:UNSUPPORTED-METHOD",
        "corona:INTERNAL-ERROR"
    )
    let $statusCode :=
        if(starts-with($exceptionCode, "corona:INVALID-") or starts-with($exceptionCode, "corona:MISSING-") or $exceptionCode = $isA400)
        then 400
        else if(ends-with($exceptionCode, "-NOT-FOUND"))
        then 404
        else if($exceptionCode = $isA500)
        then 500
        else 400

    let $set := xdmp:set-response-code($statusCode, $message)
    let $add := xdmp:add-response-header("Date", string(current-dateTime()))
    return
        if($outputFormat = "xml")
        then
            <corona:error>
                <corona:status>{ $statusCode }</corona:status>
                <corona:code>{ $exceptionCode }</corona:code>
                <corona:message>{ $message }</corona:message>
            </corona:error>
        else
            json:serialize(json:document(
                json:object((
                    "error", json:object((
                        "status", $statusCode,
                        "code", $exceptionCode,
                        "message", $message
                    ))
                ))
            ))
};

declare function common:errorFromException(
    $exception as element(),
    $outputFormat as xs:string
)
{
    if($exception/*:code = "SEC-ROLEDNE")
    then common:error("corona:INVALID-PERMISSION", concat("The role '", $exception/*:data/*:datum[. != "sec:role-name"], "' does not exist."), $outputFormat)
    else if(starts-with($exception/*:name, "corona:") or starts-with($exception/*:name, "json:"))
    then common:error($exception/*:name, $exception/*:message, $outputFormat)
    else (
        xdmp:log($exception),
        common:error("corona:INTERNAL-ERROR", concat($exception/*:message, " (", $exception/*:format-string, ")"), $outputFormat)
    )
};

declare function common:castFromJSONType(
    $value as xs:anySimpleType,
    $type as xs:string
)
{
    common:castFromJSONType(
        if($type = "boolean")
        then <item boolean="{ $value }"/>
        else <item type="{ $type }">{ $value }</item>
    )
};

declare function common:castFromJSONType(
    $value as element()
)
{
    if($value/@type = "number" and $value castable as xs:double)
    then xs:double($value)

    else if(exists($value/@boolean))
    then $value/@boolean = "true"

    else if($value/@type = "date" and exists($value/@normalized-date))
    then xs:dateTime($value/@normalized-date)
    else if($value/@type = "date")
    then dateparser:parse(string($value))

    else if($value/@type = "xml")
    then $value/*

    else xs:string($value)
};

declare function common:castAs(
    $value as xs:anySimpleType,
    $type as xs:string
)
{
    if($type = "string") then xs:string($value)
    else if($type = "boolean") then xs:boolean($value)
    else if($type = "decimal") then xs:decimal($value)
    else if($type = "float") then xs:float($value)
    else if($type = "double") then xs:double($value)
    else if($type = "duration") then xs:duration($value)
    else if($type = "dateTime") then dateparser:parse($value)
    else if($type = "time") then xs:time($value)
    else if($type = "date") then xs:date($value)
    else if($type = "gYearMonth") then xs:gYearMonth($value)
    else if($type = "gYear") then xs:gYear($value)
    else if($type = "gMonthDay") then xs:gMonthDay($value)
    else if($type = "gDay") then xs:gDay($value)
    else if($type = "gMonth") then xs:gMonth($value)
    else if($type = "hexBinary") then xs:hexBinary($value)
    else if($type = "base64Binary") then xs:base64Binary($value)
    else if($type = "QName") then xs:QName($value)
    else if($type = "integer") then xs:integer($value)
    else if($type = "nonPositiveInteger") then xs:nonPositiveInteger($value)
    else if($type = "negativeInteger") then xs:negativeInteger($value)
    else if($type = "long") then xs:long($value)
    else if($type = "int") then xs:int($value)
    else if($type = "short") then xs:short($value)
    else if($type = "byte") then xs:byte($value)
    else if($type = "nonNegativeInteger") then xs:nonNegativeInteger($value)
    else if($type = "unsignedLong") then xs:unsignedLong($value)
    else if($type = "unsignedInt") then xs:unsignedInt($value)
    else if($type = "unsignedShort") then xs:unsignedShort($value)
    else if($type = "unsignedByte") then xs:unsignedByte($value)
    else if($type = "positiveInteger") then xs:positiveInteger($value)
    else xs:string($value)
};

declare function common:humanOperatorToMathmatical(
    $operator as xs:string?
) as xs:string
{
    if($operator = "eq")
    then "="
    else if($operator = "ne")
    then "!="
    else if($operator = "lt")
    then "<"
    else if($operator = "le")
    then "<="
    else if($operator = "gt")
    then ">"
    else if($operator = "ge")
    then ">="
    else "="
};

declare function common:translateSnippet(
    $snippet as element(search:snippet),
    $outputType as xs:string
) as item()*
{
    let $results :=
        for $match in $snippet/search:match
        return
            string-join(
                for $node in $match/node()
                return
                    if($node instance of element(search:highlight))
                    then concat("<span class='hit'>", string($node), "</span>")
                    else string($node)
            , "")
    return
        if($outputType = "json")
        then json:array($results)
        else $results
};

declare function common:dualStrftime(
    $format as xs:string,
    $date1 as xs:dateTime,
    $date2 as xs:dateTime
) as xs:string
{
	let $regex := "(%%)|(@@)|(%#.)|(%.)|(@#.)|(@.)"
    let $bits :=
        for $match in analyze-string($format, $regex)/*
        return
            if($match/self::*:non-match) then string($match)
            else if($match/*:group/@nr = 1) then "%"
            else if($match/*:group/@nr = 2) then "@"
            else if($match/*:group/@nr = (3, 4)) then xdmp:strftime(string($match), $date1)
            else if($match/*:group/@nr = (5, 6)) then xdmp:strftime(replace(string($match), "@", "%"), $date2)
            else string($match)
    return string-join($bits, "")
};

declare function common:getContentType(
    $uri as xs:string?,
    $contentType as xs:string?
) as xs:string?
{
    if(exists($contentType))
    then $contentType
    else if(exists($uri))
    then
        let $extension := tokenize($uri, "\.")[last()]
        return
            if($extension = ("json", "xml"))
            then $extension
            else if($extension = ("txt", "text"))
            then "text"
            else ()
    else ()
};

declare function common:getOutputFormat(
    $contentType as xs:string*,
    $outputFormat as xs:string?
) as xs:string
{
    if(exists($outputFormat))
    then $outputFormat
    else if($contentType = ("json", "xml"))
    then $contentType
    else "json"
};

declare function common:processTXID(
    $txid as xs:string,
    $forceHostMatching as xs:boolean
) as map:map
{
    let $map := map:map()
    let $bits := tokenize($txid, ":")
    let $hostID :=
        if($bits[1] castable as xs:unsignedLong)
        then xs:unsignedLong($bits[1])
        else error(xs:QName("corona:INVALID-TRANSACTION"), "Invalid txid: the transaction id contains malformed data")
    let $hostName := try {
        xdmp:host-name($hostID)
    }
    catch ($e) {
        error(xs:QName("corona:INVALID-TRANSACTION"), "Invalid txid: the transaction id contains malformed data")
    }
    let $test :=
        if($forceHostMatching and $hostID != xdmp:host())
        then error(xs:QName("corona:INVALID-TRANSACTION-HOST"), "Cannot process this transaction on this host, must be processed on the host that started the transaction")
        else ()
    let $id :=
        if($bits[2] castable as xs:unsignedLong)
        then xs:unsignedLong($bits[2])
        else error(xs:QName("corona:INVALID-TRANSACTION"), "Invalid txid: the transaction id contains malformed data")
    let $set := map:put($map, "id", $id)
    let $set := map:put($map, "hostName", $hostName)
    let $set := map:put($map, "hostID", $hostID)
    return $map
};

declare function common:execute(
    $functionName as xs:string,
    $txid as xs:string?
) as item()*
{
    if(exists($txid))
    then common:executeInTransaction($functionName, $txid, 0, (), (), (), (), (), (), ())
    else xdmp:apply(xdmp:function(xs:QName($functionName)))
};

declare function common:execute(
    $functionName as xs:string,
    $txid as xs:string?,
    $arg1 as item()*
) as item()*
{
    if(exists($txid))
    then common:executeInTransaction($functionName, $txid, 1, $arg1, (), (), (), (), (), ())
    else xdmp:apply(xdmp:function(xs:QName($functionName)), $arg1)
};

declare function common:execute(
    $functionName as xs:string,
    $txid as xs:string?,
    $arg1 as item()*,
    $arg2 as item()*
) as item()*
{
    if(exists($txid))
    then common:executeInTransaction($functionName, $txid, 2, $arg1, $arg2, (), (), (), (), ())
    else xdmp:apply(xdmp:function(xs:QName($functionName)), $arg1, $arg2)
};

declare function common:execute(
    $functionName as xs:string,
    $txid as xs:string?,
    $arg1 as item()*,
    $arg2 as item()*,
    $arg3 as item()*
) as item()*
{
    if(exists($txid))
    then common:executeInTransaction($functionName, $txid, 3, $arg1, $arg2, $arg3, (), (), (), ())
    else xdmp:apply(xdmp:function(xs:QName($functionName)), $arg1, $arg2, $arg3)
};

declare function common:execute(
    $functionName as xs:string,
    $txid as xs:string?,
    $arg1 as item()*,
    $arg2 as item()*,
    $arg3 as item()*,
    $arg4 as item()*
) as item()*
{
    if(exists($txid))
    then common:executeInTransaction($functionName, $txid, 4, $arg1, $arg2, $arg3, $arg4, (), (), ())
    else xdmp:apply(xdmp:function(xs:QName($functionName)), $arg1, $arg2, $arg3, $arg4)
};

declare function common:execute(
    $functionName as xs:string,
    $txid as xs:string?,
    $arg1 as item()*,
    $arg2 as item()*,
    $arg3 as item()*,
    $arg4 as item()*,
    $arg5 as item()*
) as item()*
{
    if(exists($txid))
    then common:executeInTransaction($functionName, $txid, 5, $arg1, $arg2, $arg3, $arg4, $arg5, (), ())
    else xdmp:apply(xdmp:function(xs:QName($functionName)), $arg1, $arg2, $arg3, $arg4, $arg5)
};

declare function common:execute(
    $functionName as xs:string,
    $txid as xs:string?,
    $arg1 as item()*,
    $arg2 as item()*,
    $arg3 as item()*,
    $arg4 as item()*,
    $arg5 as item()*,
    $arg6 as item()*
) as item()*
{
    if(exists($txid)) then
    common:executeInTransaction($functionName, $txid, 6, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6, ())
    else xdmp:apply(xdmp:function(xs:QName($functionName)), $arg1, $arg2, $arg3, $arg4, $arg5, $arg6)
};

declare function common:execute(
    $functionName as xs:string,
    $txid as xs:string?,
    $arg1 as item()*,
    $arg2 as item()*,
    $arg3 as item()*,
    $arg4 as item()*,
    $arg5 as item()*,
    $arg6 as item()*,
    $arg7 as item()*
) as item()*
{
    if(exists($txid)) then
    common:executeInTransaction($functionName, $txid, 7, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $arg7)
    else xdmp:apply(xdmp:function(xs:QName($functionName)), $arg1, $arg2, $arg3, $arg4, $arg5, $arg6, $arg7)
};

declare private function common:executeInTransaction(
    $functionName as xs:string,
    $txid as xs:string,
    $numArgs as xs:integer,
    $arg1 as item()*,
    $arg2 as item()*,
    $arg3 as item()*,
    $arg4 as item()*,
    $arg5 as item()*,
    $arg6 as item()*,
    $arg7 as item()*
) as item()*
{
    let $id := map:get(common:processTXID($txid, true()), "id")

    let $argMap := map:map()
    let $set := (
        map:put($argMap, "arg1", $arg1),
        map:put($argMap, "arg2", $arg2),
        map:put($argMap, "arg3", $arg3),
        map:put($argMap, "arg4", $arg4),
        map:put($argMap, "arg5", $arg5),
        map:put($argMap, "arg6", $arg6),
        map:put($argMap, "arg7", $arg7)
    )

    let $modulePrefix := tokenize($functionName, ":")[1]
    let $modulePath :=
        if($modulePrefix = "store")
        then "corona/lib/store.xqy"
        else ()
    let $moduleNamespace :=
        if($modulePrefix = "store")
        then "http://marklogic.com/corona/store"
        else ()

    let $argumentString := string-join(
            for $argNum in (1 to $numArgs)
            return concat("map:get($argMap, 'arg", $argNum, "')")
        , ", ")

    let $query := concat('
        xquery version "1.0-ml";
        import module namespace ', $modulePrefix , '="', $moduleNamespace, '" at "', $modulePath, '";

        declare variable $argMap as map:map external;

        ', $functionName, '(', $argumentString, ')')

    return
        try {
            xdmp:eval($query, (xs:QName("argMap"), $argMap), <options xmlns="xdmp:eval"><transaction-id>{ $id }</transaction-id></options>)
        }
        catch ($e) {
            if($e/*:code = "XDMP-NOTXN")
            then error(xs:QName("corona:UNKNOWN-TRANSACTION"), concat("The transaction with ID '", $txid, "' was not found on this server"))
            else xdmp:rethrow()
        }
};
