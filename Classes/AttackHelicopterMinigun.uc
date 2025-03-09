class AttackHelicopterMinigun extends GGMinigunComponentsContent;

var AttackHelicopterVehicle mHelicopter;
var GGGoat mDummyGoat;

function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	if(!mManualStart)
    {
        StartWeaponTimers();
    }
    if(PlayerController( mHelicopter.Controller ) != none)
    {
    	GGPlayerInput( PlayerController( mHelicopter.Controller ).PlayerInput ).RegisterKeyStateListner( KeyState );
    }
    mGoat = GGGoat(GetOwnerPawn());

	mCrosshairActor.SetHidden(false);
}

function DetachFromPlayer( optional bool removeWeaponInstantly, optional bool keepWeaponAlive )
{
	//Survivor try to steal the weapon, ignore him
	if(removeWeaponInstantly && keepWeaponAlive)
		return;
	if( mRevvingUp || mGunFiring )
    {
        StopFiring( false );
    }

    if( mGoat != none && PlayerController( mGoat.Controller ) != none)
    {
        GGPlayerInput( PlayerController( mGoat.Controller ).PlayerInput ).UnregisterKeyStateListner( KeyState );
    }
    mGoat=none;

    mCrosshairActor.SetHidden(true);
}

function AttachToSurvivor( GGNpcSurvivorAbstract survivor, name survivorWeaponBoneName );

function GGPawn GetOwnerPawn()
{
	if(mDummyGoat == none || mDummyGoat.bPendingDelete)
	{
		SpawnDummyGoat();
	}

	return mDummyGoat;
}

function SpawnDummyGoat()
{
	mDummyGoat = Spawn(class'GGGoat', mHelicopter,, vect(-10000, -10000, -10000),,,true);
	mDummyGoat.SetDrawScale(0.0000001f);
	mDummyGoat.SetHidden(true);
	mDummyGoat.SetPhysics(PHYS_None);
	mDummyGoat.SetCollisionType(COLLIDE_NoCollision);
	mDummyGoat.CollisionComponent=none;
}

function Tick( float delta )
{
	local vector sLoc;
	local rotator sRot;

	if(mDummyGoat == none || mDummyGoat.bPendingDelete)
	{
		SpawnDummyGoat();
	}

	mWeaponMesh.GetSocketWorldLocationAndRotation( mBarrelNames[mCurrentbarrel], sLoc, sRot);
	if(mDummyGoat.Location != sLoc)
	{
		mDummyGoat.SetPhysics(PHYS_None);
		mDummyGoat.SetLocation(sLoc);
		mDummyGoat.SetRotation(sRot);
	}

	super.Tick(delta);
}

function StartFiring()
{
    local GGPawn ownerPawn;

    mRevvingUp = false;

    ownerPawn = GetOwnerPawn();

    ActivateShotEffects();

    mGunFiring = true;

    if( mFiringLoopAC == none )
    {
        mFiringLoopAC = ownerPawn.CreateAudioComponent( mFireLoopSound, false );
    }

    if( mFiringLoopAC != none )
    {
        mFiringLoopAC.SoundCue = mFireLoopSound;
        mFiringLoopAC.PitchMultiplier=2.f;
        mFiringLoopAC.Play();
    }

    if(!ownerPawn.IsTimerActive(mFireFunctionName, self))
        ownerPawn.SetTimer(mFireInterval, true, mFireFunctionName, self);
}

function UpdateCrosshair()
{
	local vector			StartTrace, EndTrace, AdjustedAim;
	local Array<ImpactInfo>	ImpactList;
	local ImpactInfo 		RealImpact;
	local float 			Radius;

	if(mGoat != None)
	{
		StartTrace = mGoat.location + mAimOffsetStart;

		AdjustedAim = vector(mHelicopter.Rotation + rot(-2730, 0, 0));

		Radius = mCrosshairActor.SkeletalMeshComponent.SkeletalMesh.Bounds.SphereRadius;
		EndTrace = StartTrace + AdjustedAim * (mRange - Radius);

		RealImpact = CalcWeaponFire(StartTrace, EndTrace, ImpactList);

		mCrosshairActor.UpdateCrosshair(RealImpact.hitLocation, -AdjustedAim);
	}
}

function ProcessInstantHit(ImpactInfo Impact, optional int NumHits)
{
	super.ProcessInstantHit(Impact, NumHits);

	if(GGApexDestructibleActor(Impact.HitActor) != none)
	{
		Impact.HitActor.TakeDamage(10000000, GetOwnerPawn().Controller, Impact.HitLocation, mImpactForce * Impact.RayDir, class'GGDamageTypeAbility', Impact.HitInfo, GetOwnerPawn());
	}
}

DefaultProperties
{
	mConsumeAmmo=false
	mMaxAmmo=5999994

	mRange=100000.0f
	mSpread=1.0f
	mImpactForce=300.0f
	mFireInterval=0.05f

	mBaseDamage=200.0f
	mAimOffsetStart=(X=0,Y=0,Z=0)

	mCrosshairActive=true;
}