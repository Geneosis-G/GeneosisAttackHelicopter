class ExplosiveMissile extends GGExplosiveActorAbstract;

var MissileLauncher mLauncher;

var float missileSpeed;
var float rotationInterpSpeed;
var bool mIsLaunched;

var PhysicalMaterial mPhysMat;
var ParticleSystemComponent mTrailParticle;
var ParticleSystem mTrailEffectTemplate;
var SoundCue mMissileLaunchSound;

simulated event PostBeginPlay()
{
	Super.PostBeginPlay();
	//WorldInfo.Game.Broadcast(self, "LaserSwordSpawned=" $ self);
	StaticMeshComponent.BodyInstance.CustomGravityFactor=0.f;

	mPhysProp = GGPhysicalMaterialProperty( mPhysMat.GetPhysicalMaterialProperty( class'GGPhysicalMaterialProperty' ) );
	mDamage 			= mPhysProp.GetExplosionDamage();
	mDamageRadius 		= mPhysProp.GetExplosionDamageRadius();
	mExplosiveMomentum  = mPhysProp.GetExplosiveMomentum();
	//WorldInfo.Game.Broadcast(self, "mDamage=" $ mDamage);

	SetCollision(false, false);
	SetCollisionType(COLLIDE_NoCollision);
	CollisionComponent.SetActorCollision(false, false);
	CollisionComponent.SetBlockRigidBody(false);
	CollisionComponent.SetNotifyRigidBodyCollision(false);
}

function Launch()
{
	if(mIsLaunched)
		return;

	SetBase(none);

	SetPhysics(PHYS_RigidBody);
	CollisionComponent.WakeRigidBody();
	StaticMeshComponent.SetRBLinearVelocity(vector(mLauncher.mHelicopter.Rotation) * missileSpeed);
	mTrailParticle = WorldInfo.MyEmitterPool.SpawnEmitter( mTrailEffectTemplate, Location, Rotation, self );
	PlaySound(mMissileLaunchSound);
	mIsLaunched = true;

	// Dissapear after 10 seconds of flight
	SetTimer(10.f, false, NameOf(ManageExplosion));
}

function EnableCollisions()
{
	//WorldInfo.Game.Broadcast(self, "EnableCollisions");
	SetCollision(true, true);
	SetCollisionType(COLLIDE_BlockAll);
	CollisionComponent.SetActorCollision(true, true);
	CollisionComponent.SetBlockRigidBody(true);
	CollisionComponent.SetNotifyRigidBodyCollision(true);
}

function bool shouldIgnoreActor(Actor act)
{
	//WorldInfo.Game.Broadcast(self, "shouldIgnoreActor=" $ act);
	return (
	act == none
	|| Volume(act) != none
	|| GGApexDestructibleActor(act) != none
	|| act == self
	|| act == Owner
	|| act.Owner == Owner
	|| !mIsLaunched);
}

function bool ShouldExplode( int damageDealt, class< DamageType > damageType, vector momentum, Actor damageCauser );//No explosions caused by other code than this one

simulated event TakeDamage( int damage, Controller eventInstigator, vector hitLocation, vector momentum, class< DamageType > damageType, optional TraceHitInfo hitInfo, optional Actor damageCauser )
{
	super.TakeDamage(damage, eventInstigator, hitLocation, momentum, damageType, hitInfo, damageCauser);
	//WorldInfo.Game.Broadcast(self, "TakeDamage");
	if(shouldIgnoreActor(damageCauser))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "TakeDamage=" $ damageCauser);
	ManageExplosion(none, none, class'GGDamageTypeZombieSurvivalMode');
}

event Bump( Actor Other, PrimitiveComponent OtherComp, Vector HitNormal )
{
    super.Bump(Other, OtherComp, HitNormal);
	//WorldInfo.Game.Broadcast(self, "Bump");
	if(shouldIgnoreActor(other))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "Bump=" $ other);
	ManageExplosion(none, none, class'GGDamageTypeZombieSurvivalMode');
}

event RigidBodyCollision(PrimitiveComponent HitComponent, PrimitiveComponent OtherComponent, const out CollisionImpactData RigidCollisionData, int ContactIndex)
{
	super.RigidBodyCollision(HitComponent, OtherComponent, RigidCollisionData, ContactIndex);
	//WorldInfo.Game.Broadcast(self, "RBCollision");
	if(shouldIgnoreActor(OtherComponent.Owner))
    {
        return;
    }
	//WorldInfo.Game.Broadcast(self, "RBCollision=" $ OtherComponent.Owner);
	ManageExplosion(none, none, class'GGDamageTypeZombieSurvivalMode');
}

simulated event Tick( float deltaTime )
{
	local GGPawn gpawn;
	local vector targetLoc, newDirection;
	local float oldSpeed;
	// Try to prevent pawns from walking on it
	foreach BasedActors(class'GGPawn', gpawn)
	{
		ManageExplosion(none, none, class'GGDamageTypeZombieSurvivalMode');
	}

	super.Tick(deltaTime);

	if(mLauncher == none)
		return;

	if(!mIsLaunched)
	{
		if(Location != mLauncher.mLauncherMesh.GetPosition())
		{
			SetLocation(mLauncher.mLauncherMesh.GetPosition());
			SetRotation(mLauncher.mHelicopter.Rotation);
			SetBase(mLauncher.mHelicopter);
		}
	}
	else
	{
		// Enable collisions when far enough from heli
		if(CollisionType == COLLIDE_NoCollision && VSize(Location-mLauncher.mHelicopter.Location) > 500.f)
		{
			EnableCollisions();
		}
		// Aim at target
		targetLoc=mLauncher.mHelicopter.GetTargetPos();
		if(!IsZero(targetLoc))
		{
			oldSpeed = VSize(Velocity);
			if(VSize(Location-targetLoc) < 1.f)
			{
				ManageExplosion(none, none, class'GGDamageTypeZombieSurvivalMode');
			}
			else if(oldSpeed > 0.f)
			{
				// Rotate the missile in the direction of its velocity
				StaticMeshComponent.SetRBRotation(rotator(Normal(Velocity)) + rot(-16384, 0, 0));

				newDirection=AimAt(deltaTime, targetLoc);
				StaticMeshComponent.SetRBLinearVelocity(newDirection * missileSpeed);
			}
		}
	}
}

function vector AimAt(float deltaTime, vector aimLocation)
{
	local rotator dir, expectedDir;
	local vector newDirection;

	dir=rotator(Normal(StaticMeshComponent.GetRBLinearVelocity()));
	expectedDir=rotator(Normal(aimLocation-Location));

	newDirection=Normal(vector(RInterpTo( dir, expectedDir, deltaTime, rotationInterpSpeed, false )));

	return newDirection;
}

function ManageExplosion( Controller eventInstigator, Actor damageCauser, class< DamageType > damageType  )
{
	if(mTrailParticle.bIsActive)
	{
		mTrailParticle.DeactivateSystem();
		mTrailParticle.KillParticlesForced();
	}

	super.ManageExplosion(eventInstigator, damageCauser, damageType);
}

simulated function bool HurtRadius
(
	float				BaseDamage,
	float				DamageRadius,
	class<DamageType>	DamageType,
	float				Momentum,
	vector				HurtOrigin,
	optional Actor		IgnoredActor,
	optional Controller InstigatedByController = Instigator != None ? Instigator.Controller : None,
	optional bool       bDoFullDamage
)
{
	local GGNPCMMOEnemy	Victim;
	local GGNpcZombieGameModeAbstract zVictim;
	local bool bCausedDamage;
	local TraceHitInfo HitInfo;

	// Prevent HurtRadius() from being reentrant.
	if ( bHurtEntry )
		return false;

	bCausedDamage = super.HurtRadius(BaseDamage, DamageRadius, DamageType, Momentum, HurtOrigin, IgnoredActor, InstigatedByController, bDoFullDamage);
	bHurtEntry = true;

	foreach CollidingActors( class'GGNPCMMOEnemy', Victim, DamageRadius, HurtOrigin,,, HitInfo )
	{
		Victim.TakeDamageFrom( int( RandRange( 50, 100 ) ),,class'GGDamageTypeExplosiveActor' );
	}

	foreach CollidingActors( class'GGNpcZombieGameModeAbstract', zVictim, DamageRadius, HurtOrigin,,, HitInfo )
	{
		zVictim.TakeDamage( int( RandRange( 50, 100 ) ), none, zVictim.Location, vect(0,0,0), class'GGDamageTypeZombieSurvivalMode' );
	}

	bHurtEntry=false;
	return bCausedDamage;
}

DefaultProperties
{
	mPhysMat = PhysicalMaterial'Zombie_Physical_Materials.Explosives.PhysMat_Explosive_heliumCart'

	Physics=PHYS_None

	bNoDelete=false
	bStatic=false
	mBlockCamera=false

	missileSpeed=5000.f
	rotationInterpSpeed=10.f

	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Space_BottleRockets.Meshes.BottleRocket_02'
		Materials(0)=Material'Office_Set_01.Materials.PaperBoxGray_01'
		Materials(1)=Material'Office_Set_01.Materials.PaperBoxGray_01'
		Materials(2)=Material'Office_Set_01.Materials.PaperBoxGray_01'
		bNotifyRigidBodyCollision = true
		ScriptRigidBodyCollisionThreshold = 1
        CollideActors = true
        BlockActors = true
		Translation=(X=0, Y=0, Z=0)
		Rotation=(Pitch=-16384,Yaw=0,Roll=0)//16384 //32767
		Scale3D=(X=1.f, Y=1.f, Z=2.f)
	End Object

	bCollideActors=true
	bBlockActors=true
	bCollideWorld=true

	mTrailEffectTemplate=ParticleSystem'JetPack.Effects.JetThrust'

	mMissileLaunchSound=SoundCue'Space_CommandoBridge_Sounds.LiftAndGo.Rocket_Takeoff_Cue'
}