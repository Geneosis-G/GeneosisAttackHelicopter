class AttackHelicopterSeat extends GGVehiclePassengerSeat;

function GetInVechile( Pawn userPawn )
{
	local GGGoat goatUser;
	local vector offsetPostion, localUpVec, localForwardVec, localSideVec;

	goatUser = GGGoat( userPawn );
	if( goatUser != none )
	{
		// This stops the goat's head from colliding with the bike, which after call to SetBase causes exploding collisions.
		// Normally SetCollision and SetHardAttach should take care of this, but the goat's head is special case.
		goatUser.SetHeadFixed( true );

		if( userPawn.mesh != none )
		{
			mRBChannelDriverBeforeDriving = userPawn.mesh.RBChannel;
			userPawn.mesh.SetRBChannel( RBCC_Untitled2 );
		}
	}

	localUpVec = vect( 0.0f, 0.0f, 1.0f ) * 160.0f;
	localForwardVec = vect( 1.0f, 0.0f, 0.0f ) * 200.0f;
	localSideVec = vect( 0.0f, 1.0f, 0.0f ) * 60.0f;
	offsetPostion = localUpVec + localForwardVec + localSideVec;

	mDriverMeshTranslationBefore = userPawn.mesh.Translation;
	userPawn.mesh.SetTranslation( offsetPostion );				// Offset the user to get the correct position

	if(goatUser != none)
	{
		goatUser.mAnimNodeSlot.PlayCustomAnim( 'Brake', 0.1f, , , true );

		userPawn.mesh.PhysicsAssetInstance.ForceAllBodiesBelowUnfixed( goatUser.mNeckBoneName, goatUser.mesh.PhysicsAsset, goatUser.mesh, true );
	}
}

function GetOutOfVehicle( Pawn userPawn )
{
	local GGGoat goatUser;

	super.GetOutOfVehicle( userPawn );

	goatUser = GGGoat( userPawn );
	if( goatUser != none )
	{
		goatUser.mesh.PhysicsAssetInstance.ForceAllBodiesBelowUnfixed( goatUser.mNeckBoneName, goatUser.mesh.PhysicsAsset, goatUser.mesh, false );
	}
}

DefaultProperties
{
	mCameraLookAtOffset=(X=0.0f,Y=0.0f,Z=0.0f)

	mDriverPosOffsetX=0.0f
	mDriverPosOffsetZ=0.0f

	bDriverIsVisible=true

	// Vehicle
	ExitPositions(0)=(X=200.0f,Y=200.0f,Z=0.0f)
	ExitPositions(1)=(X=0.0f,Y=200.0f,Z=0.0f)
	ExitPositions(2)=(X=-200.0f,Y=200.0f,Z=0.0f)
	ExitPositions(3)=(X=200.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(4)=(X=0.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(5)=(X=-200.0f,Y=-200.0f,Z=0.0f)

}
