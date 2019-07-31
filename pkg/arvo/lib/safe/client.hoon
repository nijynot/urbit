/-  safe-applet, *safe-client, common=safe-common
/+  signatures=safe-signatures, *safe-common
::  Safe client library
::
::    The client library contains all the functionality for working with the
::    node:client data structure, which represents the client side view of the
::    world.
::
|%
::  +from-transport: changes
::
::    TODO: I've spent the entire project so far thinking in terms of transpor
::
++  from-transport
  |%
  ++  event-log-item
    |=  [app-map=(map @t vase) app=term e=transport-event-log-item:common]
    ^-  (unit event-log-item:common)
    ::
    ?.  ?=(%log -.e)
      `e
    ::
    =/  node-vase=vase           (~(got by app-map) app)
    ::
    =/  user-event-mold=vase     (slap node-vase [%limb %user-event])
    =/  private-event-mold=vase  (slap node-vase [%limb %private-event])
    ::
    =/  user-event=vase  (slam user-event-mold %noun user-event.e)
    =/  private-event=vase  (slam private-event-mold %noun private-event.e)
    ::
    ::  TODO: The point at which we reconstitute an event from transport is
    ::  probably the correct time to perform the signature verification.
    ::
    `[%log msg-signature.e route.e user-event private-event]
  ::
  ++  snapshot
    |=  [app-map=(map @t vase) s=transport-snapshot:common]
    ^-  snapshot:common
    ::
    =/  node-vase=vase           (~(got by app-map) app-type.s)
    ::
    =/  snapshot-mold=vase  (slap node-vase [%limb %snapshot])
    =/  snapshot-vase=vase  (slam snapshot-mold %noun raw-snapshot.s)
    ::
    [app-type.s top-state.s signature-type.s snapshot-vase children.s]
  --
::  +applies a diff to a client's state
::
++  apply-peer-diff
  |=  [app-map=(map @t vase) route=path =peer-diff:common client-state=node]
  ^-  node
  ::
  ?^  route
    =/  child-state=node
      %_    $
          route  t.route
      ::
          client-state
        ?~  child-state=(~(get by children.client-state) i.route)
          ::  this is the first time we've even heard of this node
          *node
        ?~  u.child-state
          ::  we've heard about this node before, but know nothing about it
          *node
        u.u.child-state
      ==
    ::
    client-state(children (~(put by children.client-state) i.route `child-state))
  ::  apply this peer-diff to the client-state
  ::
  ?-    -.peer-diff
      ::  we have a completely new snapshot which we append to history
      ::
      %snapshot
    ::
    =/  snapshot=snapshot:common
      (snapshot:from-transport app-map snapshot.peer-diff)
    ::
    %_    client-state
        partial-event-log
      :_  partial-event-log.client-state
      [id.peer-diff %snapshot snapshot]
    ::
        snapshot
      [~ snapshot]
    ==
  ::
      %event
    ::
    =/  event-item=event-log-item:common
      %-  need
      %^  event-log-item:from-transport  app-map
        app-type:(need snapshot.client-state)
      event.peer-diff
    ::
    %_    client-state
        partial-event-log
      :_  partial-event-log.client-state
      [id.peer-diff %event event-item]
    ::
        snapshot
      `(apply-event-log-item-to-state app-map event-item (need snapshot.client-state))
    ==
  ==
::  +signature-request-for: changes an abstract signature-type into a
::  signature-request for route.
::
++  signature-request-for
  |=  [route=path client-state=node]
  ^-  signature-request:common
  ::
  =/  root-state  client-state
  %-  need
  ::  we recursively walk through the client-state, returning ~ for %inherit,
  ::  otherwise returning the real
  ::
  |-
  ^-  (unit signature-request:common)
  ::
  |^  =|  built-route=path
      |-
      ?^  route
        =/  ret-val=(unit signature-request:common)
          %_  $
            built-route   (weld built-route [i.route ~])
            route         t.route
            client-state  (need (~(got by children.client-state) i.route))
          ==
        ::
        ?~  ret-val
          (get-for-node built-route client-state)
        ret-val
      ::
      (get-for-node built-route client-state)
  ::
  ++  get-for-node
    |=  [built-route=path client-state=node]
    ^-  (unit signature-request:common)
    ::
    =/  =top-state:common  (need top-state:(need snapshot.root-state))
    ::
    =/  =snapshot:common   (need snapshot.client-state)
    ?-    signature-type.snapshot
        %ship
      `[%ship ~]
    ::
        %unlinked
      `[%unlinked invited.top-state]
    ::
        %community
      :*  ~
          %linked
          [community-name.top-state original-host.top-state /]
          invited.top-state
      ==
    ::
        %self
      :*  ~
          %linked
          [community-name.top-state original-host.top-state built-route]
          invited.top-state
      ==
    ::
        %inherit
      ~
    ==
  --
::  +sign-user-message: verify that user-message is the right shape and make
::  the appropriate signatures
::
::    TODO: Split this into the node:client parts, and the signing parts to go
::    in /+ signatures.
::
::    TODO: It feels like a smell that app-map isn't part of a client-state,
::    which isn't reflected in the server-state. If we're going to let people
::    customize this thing, think about the source code being in the node?
::
++  sign-user-event
  |=  [our=@p now=@da eny=@uvJ route=path user-event=* client-state=node app-map=(map @t vase)]
  ^-  [full-signature:safe-applet full-signature:safe-applet path *]
  ::
  =/  root-request  (signature-request-for / client-state)
  =/  path-request  (signature-request-for route client-state)
  ::
  =/  app-type=@t
    |-
    ?^  route
      $(route t.route, client-state (need (~(got by children.client-state) i.route)))
    app-type:(need snapshot.client-state)
  ::  validate the user-message against the +user-event mold for this applet
  ::
  ::    what we sign and send is not the exact user-event, but the one passed
  ::    through the applet's user-event mold for validation, since this data
  ::    will be explicitly validated on the server.
  ::
  =/  node-vase=vase        (~(got by app-map) app-type)
  =/  user-event-mold=vase  (slap node-vase [%limb %user-event])
  =/  user-event=vase       (slam user-event-mold %noun user-event)
  ::
  %-  sign-raw-user-event:signatures  :*
    our
    now
    eny
    root-request
    path-request
    route
    q.user-event
  ==
--