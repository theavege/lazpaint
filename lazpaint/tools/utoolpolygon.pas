unit UToolPolygon;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UTool, UToolVectorial, BGRABitmap, BGRABitmapTypes,
  LCVectorOriginal, LCLType;

const
  EasyBezierMinimumDotProduct = 0.5;

type
  { TToolRectangle }

  TToolRectangle = class(TVectorialTool)
  protected
    function CreateShape: TVectorShape; override;
  public
    function GetContextualToolbars: TContextualToolbars; override;
  end;

  { TToolEllipse }

  TToolEllipse = class(TVectorialTool)
  protected
    function CreateShape: TVectorShape; override;
  public
    function GetContextualToolbars: TContextualToolbars; override;
  end;

  { TToolPolygon }

  TToolPolygon = class(TVectorialTool)
  protected
    function CreateShape: TVectorShape; override;
    procedure AssignShapeStyle(AMatrix: TAffineMatrix); override;
    procedure UpdateUserMode; virtual;
  public
    function GetContextualToolbars: TContextualToolbars; override;
  end;

  { TToolSpline }

  TToolSpline = class(TToolPolygon)
  private
    FCurrentMode: TToolSplineMode;
    FNextCurveMode: TEasyBezierCurveMode;
    FCurveModeHintShown: Boolean;
    function GetCurrentMode: TToolSplineMode;
    procedure SetCurrentMode(AValue: TToolSplineMode);
  protected
    function CreateShape: TVectorShape; override;
    procedure AssignShapeStyle(AMatrix: TAffineMatrix); override;
    procedure UpdateUserMode; override;
  public
    constructor Create(AManager: TToolManager); override;
    function ToolKeyPress(var key: TUTF8Char): TRect; override;
    function GetContextualToolbars: TContextualToolbars; override;
    property CurrentMode: TToolSplineMode read GetCurrentMode write SetCurrentMode;
  end;

implementation

uses LazPaintType, LCVectorRectShapes, LCVectorPolyShapes;

{ TToolEllipse }

function TToolEllipse.CreateShape: TVectorShape;
begin
  result := TEllipseShape.Create(nil);
end;

function TToolEllipse.GetContextualToolbars: TContextualToolbars;
begin
  Result:= [ctColor,ctTexture,ctShape,ctPenWidth,ctPenStyle];
end;

{ TToolRectangle }

function TToolRectangle.CreateShape: TVectorShape;
begin
  result := TRectShape.Create(nil);
end;

function TToolRectangle.GetContextualToolbars: TContextualToolbars;
begin
  Result:= [ctColor,ctTexture,ctShape,ctPenWidth,ctPenStyle,ctJoinStyle];
end;

{ TToolSpline }

function TToolSpline.GetCurrentMode: TToolSplineMode;
begin
  if Assigned(FShape) then
    FCurrentMode := ToolSplineModeFromShape(FShape);
  result := FCurrentMode;
end;

procedure TToolSpline.SetCurrentMode(AValue: TToolSplineMode);
begin
  if FCurrentMode = AValue then exit;
  FCurrentMode := AValue;
  UpdateUserMode;
end;

procedure TToolSpline.UpdateUserMode;
var
  c: TCurveShape;
begin
  if FShape = nil then exit;
  if FQuickDefine then
  begin
    FShape.Usermode := vsuCreate;
    exit;
  end;
  c := TCurveShape(FShape);
  case FCurrentMode of
  tsmMovePoint: if not (c.Usermode in [vsuEdit,vsuCreate]) then c.Usermode := vsuEdit;
  tsmCurveModeAuto: if c.Usermode <> vsuCreate then c.Usermode := vsuCurveSetAuto else
                    if c.PointCount > 1 then c.CurveMode[c.PointCount-2] := cmAuto;
  tsmCurveModeAngle: if c.Usermode <> vsuCreate then c.Usermode := vsuCurveSetAngle else
                     if c.PointCount > 1 then c.CurveMode[c.PointCount-2] := cmAngle;
  tsmCurveModeSpline: if c.Usermode <> vsuCreate then c.Usermode := vsuCurveSetCurve else
                      if c.PointCount > 1 then c.CurveMode[c.PointCount-2] := cmCurve;
  end;
end;

function TToolSpline.CreateShape: TVectorShape;
begin
  result := TCurveShape.Create(nil);
  result.Usermode := vsuCreate;
  TCurveShape(result).CosineAngle:= EasyBezierMinimumDotProduct;
  if not FCurveModeHintShown then
  begin
    Manager.ToolPopup(tpmCurveModeHint);
    FCurveModeHintShown := true;
  end;
end;

procedure TToolSpline.AssignShapeStyle(AMatrix: TAffineMatrix);
begin
  inherited AssignShapeStyle(AMatrix);
  TCurveShape(FShape).SplineStyle:= Manager.SplineStyle;
end;

constructor TToolSpline.Create(AManager: TToolManager);
begin
  inherited Create(AManager);
  FNextCurveMode := cmAuto;
end;

function TToolSpline.ToolKeyPress(var key: TUTF8Char): TRect;
var keyCode: Word;
begin
  if (Key='z') or (Key = 'Z') then
  begin
    CurrentMode:= tsmMovePoint;
    result := OnlyRenderChange;
    Key := #0;
  end else
  if (Key='i') or (Key='I') then
  begin
    keyCode := VK_INSERT;
    ToolKeyDown(keyCode);
    keyCode := VK_INSERT;
    ToolKeyUp(keyCode);
    result := EmptyRect;
  end else
  begin
    Result:=inherited ToolKeyPress(key);
    if Key='x' then Key := #0;
  end;
end;

function TToolSpline.GetContextualToolbars: TContextualToolbars;
begin
  Result:= [ctColor,ctTexture,ctShape,ctPenWidth,ctPenStyle,ctLineCap,ctSplineStyle];
end;

{ TToolPolygon }

function TToolPolygon.CreateShape: TVectorShape;
begin
  result := TPolylineShape.Create(nil);
end;

procedure TToolPolygon.AssignShapeStyle(AMatrix: TAffineMatrix);
begin
  inherited AssignShapeStyle(AMatrix);
  TCustomPolypointShape(FShape).Closed := toCloseShape in Manager.ShapeOptions;
  TCustomPolypointShape(FShape).ArrowStartKind := Manager.ArrowStart;
  TCustomPolypointShape(FShape).ArrowEndKind := Manager.ArrowEnd;
  TCustomPolypointShape(FShape).ArrowSize := Manager.ArrowSize;
  if not (self is TToolSpline) then TCustomPolypointShape(FShape).LineCap:= Manager.LineCap;
  UpdateUserMode;
end;

procedure TToolPolygon.UpdateUserMode;
begin
  if FShape = nil then exit;
  if FQuickDefine then FShape.Usermode := vsuCreate;
end;

function TToolPolygon.GetContextualToolbars: TContextualToolbars;
begin
  Result:= [ctColor,ctTexture,ctShape,ctPenWidth,ctPenStyle,ctJoinStyle,ctLineCap];
end;

initialization

  RegisterTool(ptRect,TToolRectangle);
  RegisterTool(ptEllipse,TToolEllipse);
  RegisterTool(ptPolygon,TToolPolygon);
  RegisterTool(ptSpline,TToolSpline);

end.

