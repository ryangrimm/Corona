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

import module namespace template="http://marklogic.com/corona/template" at "/corona/htools/template.xqy";
import module namespace common="http://marklogic.com/corona/common" at "/corona/lib/common.xqy";
import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
import module namespace admin="http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

declare variable $publicPrivs := <privs>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-add-response-header</priv>
    <priv>http://marklogic.com/xdmp/privileges/xslt-eval</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-eval</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-eval-in</priv>
    <priv>http://marklogic.com/xdmp/privileges/get-role-names</priv>
    <priv>http://marklogic.com/xdmp/privileges/any-uri</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-value</priv>
    <priv>http://marklogic.com/xdmp/privileges/any-collection</priv>
    <priv>http://marklogic.com/xdmp/privileges/admin-module-read</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-transaction-create</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-set-transaction-name-any</priv>
    <priv>http://marklogic.com/xdmp/privileges/status</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-login</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-invoke</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-user-roles</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-invoke-transaction</priv>
    <priv>http://marklogic.com/xdmp/privileges/complete-my-transactions</priv>
    <priv>http://marklogic.com/xdmp/privileges/get-role-ids</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-role-roles</priv>
    <priv>http://marklogic.com/xdmp/privileges/create-user</priv>
    <priv>http://marklogic.com/xdmp/privileges/remove-user</priv>
    <priv>http://marklogic.com/xdmp/privileges/user-set-password</priv>
    <priv>http://marklogic.com/xdmp/privileges/grant-my-roles</priv>
    <priv>http://marklogic.com/xdmp/privileges/grant-all-roles</priv>
    <priv>http://marklogic.com/xdmp/privileges/create-role</priv>
    <priv>http://marklogic.com/xdmp/privileges/remove-role</priv>
    <priv>http://marklogic.com/xdmp/privileges/user-add-roles</priv>
    <priv>http://marklogic.com/xdmp/privileges/role-set-default-permissions</priv>
    <priv>http://marklogic.com/xdmp/privileges/user-set-default-permissions</priv>
</privs>;

declare variable $appAdminPrivs := <privs>
</privs>;

declare variable $adminPrivileges := <privs>
    <priv>http://marklogic.com/xdmp/privileges/add-role</priv>
    <priv>http://marklogic.com/xdmp/privileges/remove-role</priv>
    <priv>http://marklogic.com/xdmp/privileges/role-add-roles</priv>
    <priv>http://marklogic.com/xdmp/privileges/role-remove-roles</priv>
    <priv>http://marklogic.com/xdmp/privileges/xdmp-add-response-header</priv>
    <priv>http://marklogic.com/xdmp/privileges/admin-module-read</priv>
    <priv>http://marklogic.com/xdmp/privileges/admin-module-write</priv>
    <priv>http://marklogic.com/xdmp/privileges/any-collection</priv>
    <priv type="uri" name="corona-transformers-uri">_/transformers/</priv> <!-- XXX - is this needed? -->
</privs>;

declare function local:user(
    $user as xs:string
) as xs:integer?
{
    try {
        xdmp:user($user)
    }
    catch ($e) {
        ()
    }
};

declare function local:role(
    $role as xs:string
) as xs:integer?
{
    try {
        xdmp:role($role)
    }
    catch ($e) {
        ()
    }
};

declare function local:setupRole(
    $role as xs:string,
    $description as xs:string,
	$privileges as element(privs),
	$inheritFrom as xs:string*
) as empty-sequence()
{
	(: First make sure that the role exists :)
    let $roleID := xdmp:eval('
		import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
		declare variable $role as xs:string external;
		declare variable $description as xs:string external;
		declare variable $inheritFrom as element(roles) external;

		try {
			sec:get-role-ids($role)
		}
		catch ($e) {
			sec:create-role($role, $description, for $i in $inheritFrom/* return string($i), (), ())
		}

	', (xs:QName("role"), $role, xs:QName("description"), $description, xs:QName("inheritFrom"), <roles>{ for $i in $inheritFrom return <role>{ $i }</role> }</roles>))

	(: Grant the URI privileges to the role :)
    let $createURIPrivs := xdmp:eval('
		import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
		declare variable $privileges as element(privs) external;

		for $priv in $privileges/*
		let $privExists := try {
				exists(sec:get-privilege(string($priv), "uri"))
			}
			catch ($e) {
				false()
			}
		where $priv/@type = "uri" and not($privExists)
		return sec:create-privilege(string($priv/@name), string($priv), "uri", ())
	', (xs:QName("privileges"), $privileges))

	let $syncExecutePrivs := xdmp:eval('
		import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
		declare variable $role as xs:string external;
		declare variable $privileges as element(privs) external;

		let $newPrivileges := for $i in $privileges/* return string($i)
		let $existingPrivileges := for $i in sec:role-privileges($role) return string($i/sec:action)
		let $privilegesToRemove := $existingPrivileges[not(. = $newPrivileges)]

		return (
			for $priv in $privileges/*
			let $type := ($priv/@type, "execute")[1]
			where empty($priv/@type)
			return try { sec:privilege-add-roles(string($priv), $type, $role) } catch($e) {}
			,
			for $priv in $privilegesToRemove
			return sec:privilege-remove-roles($priv, "execute", $role)
		)

	', (xs:QName("role"), $role, xs:QName("privileges"), $privileges))
    return ()
};

declare function local:setupRewriter(
) as xs:boolean
{
	exists(
		for $appServerId in xdmp:server()
		let $adminConfig := admin:get-configuration()
		where admin:appserver-get-url-rewriter($adminConfig, $appServerId) != "/corona/lib/rewriter.xqy"
		return (true(), admin:save-configuration(admin:appserver-set-url-rewriter($adminConfig, $appServerId, "/corona/lib/rewriter.xqy")))[1]
	)
};

declare function local:setupErrorHandler(
) as xs:boolean
{
	exists(
		for $appServerId in xdmp:server()
		let $adminConfig := admin:get-configuration()
		where admin:appserver-get-error-handler($adminConfig, $appServerId) != "/corona/lib/error-handler.xqy"
		return (true(), admin:save-configuration(admin:appserver-set-error-handler($adminConfig, $appServerId, "/corona/lib/error-handler.xqy")))[1]
	)
};

declare function local:setupPublicRoleAndUser(
) as xs:boolean
{
	let $create := local:setupRole("corona::public", "Corona Public", $publicPrivs, ())
	return
		if(sec:user-exists("corona"))
		then false()
		else (
			true(),
			xdmp:eval('
				import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";

				sec:create-user("corona", "Default Corona User", xs:string(xdmp:random()), "corona::public", (
					xdmp:permission("corona::public", "read"),
					xdmp:permission("corona::public", "update")
				), ())
			', ())
		)[1]
};

declare function local:setupAuth(
) as xs:boolean
{
	exists(
		for $appServerId in xdmp:server()
		let $adminConfig := admin:get-configuration()
		let $needsRedirect := (
			admin:appserver-get-default-user($adminConfig, $appServerId) != xdmp:user("corona"),
			admin:appserver-get-authentication($adminConfig, $appServerId) != "application-level"
		) = true()
		let $adminConfig := admin:appserver-set-default-user($adminConfig, $appServerId, xdmp:user("corona"))
		let $adminConfig := admin:appserver-set-authentication($adminConfig, $appServerId, "application-level")
		return
			if($needsRedirect)
			then (true(), admin:save-configuration($adminConfig))[1]
			else ()
	)
};

declare function local:migrateRoles(
) as xs:boolean
{
	if(exists(local:role("corona-dev")) and empty(local:role("corona::public")))
	then (
		true(),
		sec:role-set-name("corona-dev", "corona::public")
	)
	else false()
};


if(common:isCoronaAdmin() = false())
then ()

else if((local:setupRewriter(), local:setupErrorHandler()) = true())
then xdmp:redirect-response("/config/setup")

else if(exists(local:role("corona::public")) and exists(local:user("corona")) and local:setupAuth() = true())
then xdmp:redirect-response("/config/setup")

else if(xdmp:database() != xdmp:database("Security"))
then xdmp:invoke("/config/setup/index.xqy", (), <options xmlns="xdmp:eval"><database>{ xdmp:database("Security") }</database></options>)

else if(local:migrateRoles() = true())
then xdmp:redirect-response("/config/setup")

else if(local:setupPublicRoleAndUser() = true())
then xdmp:redirect-response("/config/setup")
else

let $setup := local:setupRole("corona::app-admin", "Application Administrators", $appAdminPrivs, "corona::public")
let $setup := local:setupRole("corona-admin", "Corona Administrators", $adminPrivileges, ())

let $createUsers := xs:boolean((xdmp:get-request-field("createUsers", "false"))[1])
let $adminName := xdmp:get-request-field("adminName")
let $adminPass := xdmp:get-request-field("adminPass")

let $hasUsers :=
    try {
        exists(/sec:user[sec:role-ids/sec:role-id = xdmp:role("corona-admin")])
    }
    catch ($e) {
        false()
    }

return
    if(exists($adminName) and exists($adminPass))
    then
        let $set := sec:create-user($adminName, "Default Corona User", $adminPass, "corona-admin", (
				xdmp:permission("corona::public", "read"),
				xdmp:permission("corona::public", "update")
			), ())
        return template:apply(<div><p>Corona has been fully setup and an administrative account exist.</p></div>, "Corona Setup", (), 0, ())
    else if($createUsers)
    then template:apply(
        <div>
			<p>Before you can configure your Corona environment, you must
			create a Corona administrative user. The administrative user
			configures search behavior, output transformations, etc.</p>
            <form class="createUsers" action="/config/setup" method="GET">
                <div>
                    <h2>Corona Administrator</h2>
                    <table>
                        <tr><td>Username</td><td><input type="text" class="an" name="adminName"/></td></tr>
                        <tr><td>Password</td><td><input type="password" class="ap1" name="adminPass"/></td></tr>
                        <tr><td>Confirm Password</td><td><input type="password" class="ap2"/></td></tr>
                    </table>
                </div>
                <input type="submit" value="Submit"/>
            </form>
        </div>,
        "Create Users", (), 0, <script src="/corona/htools/js/setup.js"><!-- --></script>)
    else if($hasUsers)
	then template:apply(<div><p>Corona has been fully setup and an administrative account exist.</p></div>, "Corona Setup", (), 0, ())
	else xdmp:redirect-response("/config/setup?createUsers=true")
