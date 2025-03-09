class MissileLauncher extends DynamicSMActor;

var AttackHelicopterVehicle mHelicopter;
var StaticMeshComponent mLauncherMesh;
var ExplosiveMissile mMissile;

function SpawnNewMissile()
{
	if(mMissile != none && !mMissile.mIsLaunched)
		return;

	mMissile = Spawn(class'ExplosiveMissile', mHelicopter,, mLauncherMesh.GetPosition(), mHelicopter.Rotation);
	mMissile.mLauncher=self;
	mMissile.SetBase(mHelicopter);
	mMissile.StaticMeshComponent.SetLightEnvironment(StaticMeshComponent.lightenvironment);
}

function FireMissile()
{
	if(mMissile == none)
	{
		SpawnNewMissile();
	}

	mMissile.Launch();

	SetTimer(0.7f, false, NameOf(SpawnNewMissile));
}

DefaultProperties
{
	Begin Object name=StaticMeshComponent0
		bNotifyRigidBodyCollision=false
		ScriptRigidBodyCollisionThreshold=0.0f
		CollideActors=false
		BlockActors=false
		BlockZeroExtent=false
		BlockNonZeroExtent=false

		StaticMesh=StaticMesh'Space_Portal.Meshes.Pillarshaft2'
		Scale3D=(X=0.1f,Y=0.1f,Z=0.1f)
		Rotation=(Pitch=-16384,Yaw=0,Roll=0)//16384 //32767
	End Object
	mLauncherMesh=StaticMeshComponent0
	Components.Add(StaticMeshComponent0)

	bNoDelete=false
	bStatic=false

	//Launcher
	//StaticMesh'Heist_Props_02.mesh.Barrel_01'
	//StaticMesh'Space_Portal.Meshes.Pillarshaft'
	//StaticMesh'Space_Portal.Meshes.Pillarshaft2'

	//Missile
	//StaticMesh'Space_BottleRockets.Meshes.BottleRocket_02'
	//StaticMesh'Garage.Mesh.Garage_Tube_01'
	//StaticMesh'Space_PersonalQuarters.Meshes.Lavalamp_1'
	//StaticMesh'Space_PersonalQuarters.Meshes.Lavalamp_2'//wings
}