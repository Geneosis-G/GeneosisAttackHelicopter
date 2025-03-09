class AttackHelicopterVehicle extends GGSVehicle
	placeable;

var vector mDriverMeshTranslationBefore;

/** The name displayed in a combo */
var string mScoreActorName;

/** The maximum score this longboard is worth interacting with in a combo */
var int mScore;

var float mJumpForceSize;

var GGGoat attackHelicopterOwner;
// for some reasons those values are only valid if you read them in the mutator Tick
var float currentBaseY;
var float currentStrafe;


var int keypressedcount;
var bool goUp;
var bool goDown;
var bool forwardPressed;
var bool backPressed;
var bool leftPressed;
var bool rightPressed;
var bool isMoving;

var vector expectedPosition;
var rotator expectedRotation;
var float rotationInterpSpeed;

var AttackHelicopterMinigun mMinigun;
var array<MissileLauncher> mMissileLaunchers;
var int mCurrentMissileLauncher;
var float mMissileLaunchInterval;

var SoundCue mHelicopterLoopSoundCue;

var AudioComponent mAudioComponentLoop;

simulated event PostBeginPlay()
{
	local int i;

	super.PostBeginPlay();
	// Not working :/
	//EnableFullPerPolyCollision();

	mAudioComponentLoop = CreateAudioComponent( mHelicopterLoopSoundCue );
	mAudioComponentLoop.Play();

	for( i = 0; i < mNumberOfSeats; i++ )
	{
		// Remove normal seats
		mPassengerSeats[i].VehiclePassengerSeat.ShutDown();
		mPassengerSeats[i].VehiclePassengerSeat.Destroy();
		// Add custom seats
		mPassengerSeats[i].VehiclePassengerSeat = Spawn( class'AttackHelicopterSeat' );
		mPassengerSeats[i].VehiclePassengerSeat.SetBase( self );
		mPassengerSeats[i].VehiclePassengerSeat.mVehicleOwner = self;
		mPassengerSeats[i].VehiclePassengerSeat.mVehicleSeatIndex = i;
	}

	InitAttackHelicopter(GGGoat(Owner));
	SetOwner(none);
}

function InitAttackHelicopter(GGGoat AttackHelicopter_owner)
{
	local RB_BodyInstance bodyInst;

	attackHelicopterOwner=AttackHelicopter_owner;

	//Create and attach minigun
	AttachMinigun(Spawn(class'AttackHelicopterMinigun',,, vect(0, 0, -1000)));

	AttachMissileLaunchers();

	CollisionComponent=mesh;

	// Fix mass
    mesh.PhysicsAsset.BodySetup[0].MassScale = 1000000.f;
    bodyInst = mesh.GetRootBodyInstance();
    bodyInst.UpdateMassProperties(mesh.PhysicsAsset.BodySetup[0]);

    mesh.WakeRigidBody();
}

function AttachMinigun(AttackHelicopterMinigun minigun)
{
	mMinigun = minigun;

	mesh.AttachComponent(mMinigun.mWeaponMesh, 'Root', vect(60, 0, 40), rot(-2730, 0, -16384), vect(0.5f, 0.5f, 0.5f));

	//weapon.mWeaponMesh.SetLightEnvironment( goat.mesh.lightenvironment );

	//@todo this should probably change if we decide to make the weapon droppable
	mMinigun.mHelicopter = self;
	mMinigun.mCurrentAmmo = mMinigun.mMaxAmmo;

	if(mMinigun.mCrosshairActor == None && mMinigun.mCrosshairActive)
	{
		mMinigun.mGoat=GGGoat(mMinigun.GetOwnerPawn());
		mMinigun.SpawnCrosshair(mMinigun.mGoat);
		mMinigun.mGoat=none;
		mMinigun.mCrosshairActor.SetColor(MakeLinearColor( 1.0f, 69.f/255.f, 0.0f, 1.0f ));
		mMinigun.mCrosshairActor.SetHidden(true);
	}

	mMinigun.mReadyToFire = true;
}

function AttachMissileLaunchers()
{
	local MissileLauncher newMissileLauncher;

	newMissileLauncher=Spawn(class'MissileLauncher',,, vect(0, 0, -1000));
	mesh.AttachComponent(newMissileLauncher.mLauncherMesh, 'Root', vect(20, 20, 21), rot(0, 0, 0), vect(1.f, 1.f, 1.f));
	newMissileLauncher.mHelicopter = self;
	newMissileLauncher.SpawnNewMissile();
	mMissileLaunchers.AddItem(newMissileLauncher);

	newMissileLauncher=Spawn(class'MissileLauncher',,, vect(0, 0, -1000));
	mesh.AttachComponent(newMissileLauncher.mLauncherMesh, 'Root', vect(20, -20, 21), rot(0, 0, 0), vect(1.f, 1.f, 1.f));
	newMissileLauncher.mHelicopter = self;
	newMissileLauncher.SpawnNewMissile();
	mMissileLaunchers.AddItem(newMissileLauncher);
}

function vector GetTargetPos()
{
	return mMinigun.mCrosshairActor.Location;
}

simulated event Tick( float deltaTime )
{
	local vector camLocation, desiredDirection2D, desiredBoostDirection, totalBoostDirection;
	local rotator camRotation;

	super.Tick( deltaTime );
	isMoving=false;

	expectedRotation.Yaw=mesh.GetRotation().Yaw;
	expectedRotation.Pitch=0;
	expectedRotation.Roll=0;

	//Stop if not moving
	if(bDriving)
	{
		// Manage movements
		if(goUp)
		{
			AddImpulse( vect(0, 0, 1) * 2 * mJumpForceSize * deltaTime );
			totalBoostDirection.Z += 1;
			isMoving=true;
		}
		if(goDown)
		{
			AddImpulse( vect(0, 0, -1) * mJumpForceSize * deltaTime );
			totalBoostDirection.Z -= 1;
			isMoving=true;
		}

		if(GGLocalPlayer(PlayerController( Controller ).Player).mIsUsingGamePad)
		{
			if(abs(currentBaseY) > 0.2f)
			{
				desiredDirection2D.X=currentBaseY;
				expectedRotation.Pitch=currentBaseY * -2730;
			}
			if(abs(currentStrafe) > 0.2f)
			{
				desiredDirection2D.Y=currentStrafe;
				expectedRotation.Roll=currentStrafe * 2730;
			}
			if(IsZero(desiredDirection2D) && keypressedcount == 0)
			{
				SlowDown();
			}
			else
			{
				expectedPosition=vect(0, 0, 0);
			}
		}
		else
		{
			if(forwardPressed)
			{
				desiredDirection2D.X += 1.f;
				expectedRotation.Pitch=-2730;
			}
			if(backPressed)
			{
				desiredDirection2D.X += -1.f;
				expectedRotation.Pitch=2730;
			}
			if(leftPressed)
			{
				desiredDirection2D.Y += -1.f;
				expectedRotation.Roll=-2730;
			}
			if(rightPressed)
			{
				desiredDirection2D.Y += 1.f;
				expectedRotation.Roll=2730;
			}
			if(keypressedcount == 0)
			{
				SlowDown();
			}
			else
			{
				expectedPosition=vect(0, 0, 0);
			}
		}
		desiredDirection2D=Normal(desiredDirection2D);
		GGPlayerControllerGame( Controller ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
		desiredBoostDirection = vector(camRotation);
		expectedRotation.Yaw=camRotation.Yaw;

		if(!IsZero(desiredDirection2D))
		{
			desiredBoostDirection.Z=0;
			desiredBoostDirection=desiredDirection2D >> Rotator(desiredBoostDirection);
		}
		if(!IsZero(desiredBoostDirection))
		{
			AddImpulse( vect(0, 0, 1) * mJumpForceSize * deltaTime );
			AddImpulse( desiredBoostDirection * mJumpForceSize * deltaTime );
			totalBoostDirection = totalBoostDirection + desiredBoostDirection;
			isMoving=true;
		}
		//WorldInfo.Game.Broadcast(self, "Rotation=" $ Rotation);
		//WorldInfo.Game.Broadcast(self, "RBRotation=" $ mesh.GetRotation());

		//if acceleration not aligned with old speed, add extra speed boost
		if(mesh.GetRBLinearVelocity() dot Normal(totalBoostDirection) < 0)
		{
			AddImpulse( totalBoostDirection * mJumpForceSize * deltaTime );
		}
	}
	else
	{
		FreeFall();
	}
	// Force rotation
	mesh.SetRBRotation(RInterpTo(mesh.GetRotation(), expectedRotation, deltaTime, rotationInterpSpeed, false ));
	mesh.SetRBAngularVelocity(vect(0, 0, 0));

	UpdateBlockCamera();

	SetTireSound();
	//WorldInfo.Game.Broadcast(self, "Location=" $ mBeamVolume.Location $ "/" $ Location);
}

function SlowDown()
{
	local vector vel;

	vel=mesh.GetRBLinearVelocity();
	if(VSize(vel) > 1.f)
	{
		mesh.SetRBLinearVelocity(vel * 0.95);
		expectedPosition=vect(0, 0, 0);
	}
	else
	{
		LockPosition();
	}
}

function FreeFall()
{
	local vector vel;

	vel=mesh.GetRBLinearVelocity();
	if(vel.Z > 0 || vel.X != 0 || vel.Y != 0)
	{
		SlowDown();
	}
	else
	{
		expectedPosition=vect(0, 0, 0);
	}
}

function LockPosition()
{
	if(IsZero(expectedPosition))
	{
		expectedPosition=mesh.GetPosition();
	}
	mesh.SetRBLinearVelocity(vect(0, 0, 0));
	mesh.SetRBPosition(expectedPosition);
}

function ModifyCameraZoom( PlayerController contr, optional bool exit, optional bool passenger)
{
	local GGCameraModeVehicle orbitalCamera;
	local GGCamera.ECameraMode camMode;

	camMode=passenger?3:2;//Haxx because for some reason calling CM_Vehicle and CM_Vehicle_Passenger no longer works
	orbitalCamera = GGCameraModeVehicle( GGCamera( contr.PlayerCamera ).mCameraModes[ camMode ] );
	//WorldInfo.Game.Broadcast(self, "contr=" $ contr $ ", exit=" $ exit $ ", passenger=" $ passenger $ ", orbitalCamera=" $ orbitalCamera);
	if(exit)
	{
		orbitalCamera.mMaxZoomDistance = orbitalCamera.default.mMaxZoomDistance;
		orbitalCamera.mMinZoomDistance = orbitalCamera.default.mMinZoomDistance;
		orbitalCamera.mDesiredZoomDistance = orbitalCamera.default.mDesiredZoomDistance;
		orbitalCamera.mCurrentZoomDistance = orbitalCamera.default.mCurrentZoomDistance;
	}
	else
	{
		orbitalCamera.mMaxZoomDistance = 10000;
		orbitalCamera.mMinZoomDistance = 1500;
		orbitalCamera.mDesiredZoomDistance = CamDist;
		orbitalCamera.mCurrentZoomDistance = CamDist;
	}
}

function UpdateBlockCamera()
{
	local bool shouldBlockCamera;
	local int i;

	shouldBlockCamera=true;
	if(bDriving)
	{
		shouldBlockCamera=false;
	}
	else
	{
		for( i = 0; i < mPassengerSeats.Length; i++ )
		{
			if( mPassengerSeats[ i ].PassengerPawn != none )
			{
				shouldBlockCamera=false;
				break;
			}
		}
	}
	mBlockCamera=shouldBlockCamera;
}

/**
 * See super.
 */
function GetInVechile( Pawn userPawn )
{
	local vector offsetPostion, localUpVec, localForwardVec, localSideVec;
	local GGGoat goatUser;

	super.GetInVechile( userPawn );

	goatUser = GGGoat( userPawn );

	if( goatUser == none )
	{
		return;
	}

	localUpVec = vect( 0.0f, 0.0f, 1.0f ) * 160.0f;
	localForwardVec = vect( 1.0f, 0.0f, 0.0f ) * 200.0f;
	localSideVec = vect( 0.0f, 1.0f, 0.0f ) * -70.0f;
	offsetPostion = localUpVec + localForwardVec + localSideVec;

	mDriverMeshTranslationBefore = userPawn.mesh.Translation;
	userPawn.mesh.SetTranslation( offsetPostion );				// Offset the user to get the correct position

	goatUser.mAnimNodeSlot.PlayCustomAnim( 'Brake', 0.1f, , , true );

	goatUser.mesh.PhysicsAssetInstance.ForceAllBodiesBelowUnfixed( goatUser.mNeckBoneName, goatUser.mesh.PhysicsAsset, goatUser.mesh, true );
}

/**
 * See super.
 *
 * Overridden to register a key listener for input
 */
function bool DriverEnter( Pawn userPawn )
{
	local bool driverCouldEnter;

	driverCouldEnter = super.DriverEnter( userPawn );

	if( driverCouldEnter )
	{
		mMinigun.AttachToPlayer( none );
	}

	return driverCouldEnter;
}

/**
 * Take care of the new passenger
 */
function bool PassengerEnter( Pawn userPawn )
{
	local bool driverCouldEnter;

	driverCouldEnter = super.PassengerEnter( userPawn );

	if( driverCouldEnter )
	{
		//WorldInfo.Game.Broadcast(self, "PassengerEnter=" $ userPawn.DrivenVehicle.Controller);
		//ModifyCameraZoom(PlayerController(userPawn.DrivenVehicle.Controller), false, true);
	}

	return driverCouldEnter;
}

/**
 * See super.
 */
function GetOutOfVehicle( Pawn userPawn )
{
	local GGGoat goatUser;

	super.GetOutOfVehicle( userPawn );

	goUp=false;
	goDown=false;
	keypressedcount=0;
	expectedPosition=mesh.GetPosition();

	mMinigun.mGoat=GGGoat(userPawn);
	mMinigun.DetachFromPlayer();

	ClearTimer(NameOf(LaunchMissile));

	goatUser = GGGoat( userPawn );
	if( goatUser != none )
	{
		goatUser.mAnimNodeSlot.StopCustomAnim( 0.1f );
		goatUser.mesh.GlobalAnimRateScale = 1.0f;
		goatUser.mesh.PhysicsAssetInstance.ForceAllBodiesBelowUnfixed( goatUser.mNeckBoneName, goatUser.mesh.PhysicsAsset, goatUser.mesh, false );
		userPawn.mesh.SetTranslation( mDriverMeshTranslationBefore );
	}
}

function PassengerLeave( int seatIndex )
{
	//ModifyCameraZoom(PlayerController(mPassengerSeats[ seatIndex ].PassengerPawn.Controller), true, true);
	//WorldInfo.Game.Broadcast(self, "PassengerLeave=" $ mPassengerSeats[ seatIndex ].PassengerPawn.Controller);
	super.PassengerLeave(seatIndex);
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;
	local bool isMovementKeyPressed;

	super.KeyState(newKey, keyState, PCOwner);

	if(PCOwner != Controller || !ShouldListenToDriverInput())
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		// Check which key it is and then decide what to do.
		localInput = GGPlayerInputGame( PlayerController( Controller ).PlayerInput );
		isMovementKeyPressed=true;
		if( localInput.IsKeyIsPressed( "GBA_Jump", string( newKey ) ) )
		{
			goUp=true;
		}
		else if( localInput.IsKeyIsPressed( "GBA_ToggleRagdoll", string( newKey ) ) )
		{
			goDown=true;
		}
		else if(localInput.IsKeyIsPressed("GBA_Forward", string( newKey )))
		{
			forwardPressed=true;
		}
		else if(localInput.IsKeyIsPressed("GBA_Back", string( newKey )))
		{
			backPressed=true;
		}
		else if(localInput.IsKeyIsPressed("GBA_Left", string( newKey )))
		{
			leftPressed=true;
		}
		else if(localInput.IsKeyIsPressed("GBA_Right", string( newKey )))
		{
			rightPressed=true;
		}
		else
		{
			isMovementKeyPressed=false;
			if(localInput.IsKeyIsPressed("RightMouseButton", string( newKey ))|| newKey == 'XboxTypeS_LeftTrigger')
			{
				//myMut.WorldInfo.Game.Broadcast(myMut, "RightMouseButton pressed";
				if(!IsTimerActive(NameOf(AllowMissile)))
				{
					LaunchMissile();
				}
				SetTimer(mMissileLaunchInterval, true, NameOf(LaunchMissile));
			}
			//WorldInfo.Game.Broadcast(self, "newKey=" $ newKey);
		}
		/*if(newKey == 'P')
		{
			mJumpForceSize+=1000000;
			WorldInfo.Game.Broadcast(self, "mJumpForceSize=" $ mJumpForceSize);
		}
		if(newKey == 'M')
		{
			mJumpForceSize-=1000000;
			WorldInfo.Game.Broadcast(self, "mJumpForceSize=" $ mJumpForceSize);
		}*/

		if(isMovementKeyPressed)
		{
			keypressedcount++;
		}
	}
	else if( keyState == KS_Up )
	{
		// Check which key it is and then decide what to do.
		localInput = GGPlayerInputGame( PlayerController( Controller ).PlayerInput );
		isMovementKeyPressed=true;
		if( localInput.IsKeyIsPressed( "GBA_Jump", string( newKey ) ) )
		{
			goUp=false;
		}
		else if( localInput.IsKeyIsPressed( "GBA_ToggleRagdoll", string( newKey ) ) )
		{
			goDown=false;
		}
		else if(localInput.IsKeyIsPressed("GBA_Forward", string( newKey )))
		{
			forwardPressed=false;
		}
		else if(localInput.IsKeyIsPressed("GBA_Back", string( newKey )))
		{
			backPressed=false;
		}
		else if(localInput.IsKeyIsPressed("GBA_Left", string( newKey )))
		{
			leftPressed=false;
		}
		else if(localInput.IsKeyIsPressed("GBA_Right", string( newKey )))
		{
			rightPressed=false;
		}
		else
		{
			isMovementKeyPressed=false;
			if(localInput.IsKeyIsPressed("RightMouseButton", string( newKey ))|| newKey == 'XboxTypeS_LeftTrigger')
			{
				//myMut.WorldInfo.Game.Broadcast(myMut, "RightMouseButton pressed";
				ClearTimer(NameOf(LaunchMissile));
				ClearTimer(NameOf(AllowMissile));
				SetTimer(mMissileLaunchInterval, false, NameOf(AllowMissile));
			}
		}

		if(isMovementKeyPressed)
		{
			keypressedcount--;
			if(keypressedcount<0)
				keypressedcount=0;
		}
	}
}

function LaunchMissile()
{
	mMissileLaunchers[mCurrentMissileLauncher].FireMissile();
	mCurrentMissileLauncher = 1-mCurrentMissileLauncher;
}

function AllowMissile();//Dummy function, used to set a timer

function bool ShouldIgnoreActor(Actor act)
{
	if(bDriving)
	{
		return act == self
			|| act == none
			|| (GGPawn(act) == none && GGKActor(act) == none && GGSVehicle(act) == none);
	}
	else
	{
		return act != attackHelicopterOwner;
	}
}

/*********************************************************************************************
 SCORE ACTOR INTERFACE
*********************************************************************************************/

/**
 * Human readable name of this actor.
 */
function string GetActorName()
{
	return mScoreActorName;
}

/**
 * How much score this actor gives.
 */
function int GetScore()
{
	return mScore;
}

/*********************************************************************************************
 END SCORE ACTOR INTERFACE
*********************************************************************************************/

/**
 * Only care for collisions at a certain interval.
 */
function bool IsPreviousCollisionTooRecent()
{
	local float timeSinceLastCollision;

	timeSinceLastCollision = WorldInfo.TimeSeconds - mLastCollisionData.CollisionTimestamp;

	return timeSinceLastCollision < mMinTimeBetweenCollisions;
}

function bool ShouldCollide( Actor other )
{
	local GGGoat goatDriver, goatPassenger;
	local int i;

	goatDriver = GGGoat( Driver );

	if( other == Driver || IsPreviousCollisionTooRecent() || ( goatDriver != none && goatDriver.mGrabbedItem == other ) || other == mMinigun)
	{
		return false;
	}

	for( i = 0; i < mPassengerSeats.Length; i++)
	{
		goatPassenger = GGGoat( mPassengerSeats[ i ].PassengerPawn );

		if( goatPassenger != none && goatDriver.mGrabbedItem == other )
		{
			// We do not want to collide with stuff carried by driver or passengers.
			return false;
		}
	}
	//WorldInfo.Game.Broadcast(self, "Collision with " $ other);
	return true;
}

/*********************************************************************************************
 GRABBABLE ACTOR INTERFACE
*********************************************************************************************/

function bool CanBeGrabbed( Actor grabbedByActor, optional name boneName = '' )
{
	return false;
}

function OnGrabbed( Actor grabbedByActor );
function OnDropped( Actor droppedByActor );

function name GetBoneName( vector grabLocation )
{
	return '';
}

function PrimitiveComponent GetGrabbableComponent()
{
	return CollisionComponent;
}

function GGPhysicalMaterialProperty GetPhysProp()
{
	return none;
}

/*********************************************************************************************
 END GRABBABLE ACTOR INTERFACE
*********************************************************************************************/

/**
 * Set the tire sound based on how the bike is being ridden.
 */
function SetTireSound()
{
	if( bDriving && isMoving)
	{
		// Moving
		SetActiveTireSound( 0 );
	}
	else if( bDriving )
	{
		// Static
		SetActiveTireSound( 1 );
	}
	else
	{
		// Without driver
		SetActiveTireSound( 1 );
	}

	if(!mTireAudioComp.IsPlaying())
	{
		mTireAudioComp.Play();
	}
}

function Crash( Actor other, vector hitNormal );//Nope

function bool ShouldCrashKickOutDriver( vector hitVelocity, vector otherHitVelocity )
{
	return false;
}

/**
 * Called when a pawn is possessed by a controller.
 */
function NotifyOnPossess( Controller C, Pawn P )
{
	local int i;

	if(P == self)
	{
		ModifyCameraZoom(PlayerController(C));
	}
	for( i = 0; i < mPassengerSeats.Length; i++ )
	{
		if( mPassengerSeats[ i ].VehiclePassengerSeat == P )
		{
			ModifyCameraZoom(PlayerController(C), false, true);
		}
	}
}

/**
 * Called when a pawn is unpossessed by a controller.
 */
function NotifyOnUnpossess( Controller C, Pawn P )
{
	local int i;

	if(P == self)
	{
		ModifyCameraZoom( PlayerController(C), true);
	}
	for( i = 0; i < mPassengerSeats.Length; i++ )
	{
		if( mPassengerSeats[ i ].VehiclePassengerSeat == P )
		{
			ModifyCameraZoom(PlayerController(C), true, true);
		}
	}
}

DefaultProperties
{
	// --- AttackHelicopterVehicle
	rotationInterpSpeed=5.f
	mMissileLaunchInterval=0.5f

	Begin Object class=StaticMeshComponent Name=StaticMeshComp_0
		StaticMesh=StaticMesh'Helikopter.mesh.Helikopter'
		bNotifyRigidBodyCollision=true
		ScriptRigidBodyCollisionThreshold=50.0f //if too big, we won't get any notifications from collisions between kactors
		CollideActors=true
		BlockActors=true
		BlockZeroExtent=true
		BlockNonZeroExtent=true
		Translation=(Z=60)
		//Rotation=(Yaw=16384)
	End Object
	Components.Add(StaticMeshComp_0)

	mMinTimeBetweenCollisions=3.0f

	mScoreActorName="Helicopter"
	mScore=37

	//mJumpForceSize=550.f
	mJumpForceSize=14000000.f

	// --- GGSVehicle
	mGentlePushForceSize=3700.0f

	mNumberOfSeats=1

	mDriverSocketName="BoardSocket"

	mPassengerSocketNames(0)="BoardSocket"

	mCameraLookAtOffset=(X=0.0f,Y=0.0f,Z=150.0f)
	CamDist=2000.f

	// --- Actor
	bNoEncroachCheck=true
	mBlockCamera=false

	// --- Pawn
	ViewPitchMin=-16000
	ViewPitchMax=16000

	GroundSpeed=4200
	AirSpeed=4200

	// --- SVehicle
	// The speed of the vehicle is controlled by MaxSpeed, GroundSpeed, AirSpeed and TorqueVSpeedCurve
	MaxSpeed=4200					// Absolute max physics speed
	MaxAngularVelocity=110000.0f	// Absolute max physics angular velocity (Unreal angular units)

	COMOffset=(x=0.0f,y=0.0f,z=0.0f)

	bDriverIsVisible=true

	Begin Object Name=CollisionCylinder
		//CollisionRadius=100.0f
		//CollisionHeight=100.0f
		BlockNonZeroExtent=false
		BlockZeroExtent=false
		BlockActors=false
		BlockRigidBody=false
		CollideActors=false
	End Object

	CollisionSound=SoundCue'Goat_Sounds_Impact.Cue.Impact_Car_Cue'

	Begin Object class=AnimNodeSequence Name=MyMeshSequence
    End Object

	Begin Object name=SVehicleMesh
		SkeletalMesh=SkeletalMesh'Longboard.Mesh.Longboard_Skele_01'
		PhysicsAsset=PhysicsAsset'Longboard.Mesh.Longboard_Physics_01'

		bHasPhysicsAssetInstance=true
		RBChannel=RBCC_Vehicle
		RBCollideWithChannels=(Untitled2=false,Untitled3=true,Vehicle=true)
		//bNotifyRigidBodyCollision=true
		//ScriptRigidBodyCollisionThreshold=1

		Materials(0)=Material'AttackHelicopter.transparent'

		/*
		SkeletalMesh=SkeletalMesh'DrivenVehicles.mesh.Bicycle_Skele_02'
		bHasPhysicsAssetInstance=false
		*/
		//scale=0.001f
		scale=5.f
	End Object

	Begin Object Class=UDKVehicleSimCar Name=SimulationObject
		bClampedFrictionModel=true
		TorqueVSpeedCurve=(Points=((InVal=-600.0,OutVal=0.0),(InVal=-300.0,OutVal=130.0),(InVal=0.0,OutVal=210.0),(InVal=900.0,OutVal=130.0),(InVal=1450.0,OutVal=10.0),(InVal=1850.0,OutVal=0.0)))
		MaxSteerAngleCurve=(Points=((InVal=0,OutVal=35),(InVal=500.0,OutVal=18.0),(InVal=700.0,OutVal=14.0),(InVal=900.0,OutVal=9.0),(InVal=970.0,OutVal=7.0),(InVal=1500.0,OutVal=3.0)))
		SteerSpeed=85
		NumWheelsForFullSteering=2
		MaxBrakeTorque=200.0f
		EngineBrakeFactor=0.08f
	End Object
	SimObj=SimulationObject
	Components.Add(SimulationObject)

	// Vehicle
	ExitPositions(0)=(X=200.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(1)=(X=0.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(2)=(X=-200.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(3)=(X=200.0f,Y=200.0f,Z=0.0f)
	ExitPositions(4)=(X=0.0f,Y=200.0f,Z=0.0f)
	ExitPositions(5)=(X=-200.0f,Y=200.0f,Z=0.0f)

	mHelicopterLoopSoundCue=SoundCue'Goat_Sounds.Cue.Effect_helicopter_cue'
}
