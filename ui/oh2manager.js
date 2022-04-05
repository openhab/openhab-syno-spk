// Ext JS namespace
Ext.ns("SYNO.SDS.OH2");

// Translator
_V = function (category, element) {
  var translation = _TT("SYNO.SDS.OH2.Instance", category, element);
  console.log(translation);
  return translation;
};

// The application instance that gets called when clicking on the menu icon.
SYNO.SDS.OH2.Instance = Ext.extend(SYNO.SDS.AppInstance, {
  appWindowName: "SYNO.SDS.OH2.MainWindow",
  constructor: function () {
    SYNO.SDS.OH2.Instance.superclass.constructor.apply(this, arguments);
  },
});

// The application window that gets displayed.
SYNO.SDS.OH2.MainWindow = Ext.extend(SYNO.SDS.AppWindow, {
  appInstance: null,
  formPanel: null,
  constructor: function (a) {
    this.appInstance = a.appInstance;
    this.formPanel = new SYNO.SDS.OH2.MainCardPanel({
      module: this,
      owner: a.owner,
      app: this.app,
      itemId: "grid",
      region: "center",
    });
    this.id_panel = [["test", this.formPanel.PanelTest]];
    SYNO.SDS.OH2.MainWindow.superclass.constructor.call(
      this,
      Ext.apply(
        {
          resizable: false,
          maximizable: false,
          minimizable: true,
          width: 300,
          height: 200,
          layout: "fit",
          items: [this.formPanel],
        },
        a
      )
    );
  },
  onOpen: function (a) {
    SYNO.SDS.OH2.MainWindow.superclass.onOpen.call(this, a);
  },
  onRequest: function (a) {
    SYNO.SDS.OH2.MainWindow.superclass.onRequest.call(this, a);
  },
  onClose: function () {
    this.doClose();

    return false;
  },
});

// Card panel
SYNO.SDS.OH2.MainCardPanel = Ext.extend(Ext.Panel, {
  PanelTest: null,
  constructor: function (a) {
    this.app = a.app;
    this.PanelTest = new SYNO.SDS.OH2.PanelTest({ app: this.app });
    SYNO.SDS.OH2.MainCardPanel.superclass.constructor.call(
      this,
      Ext.apply(
        {
          activeItem: 0,
          layout: "card",
          items: [this.PanelTest],
          border: false,
          listeners: {
            scope: this,
            activate: this.onActivate,
            deactivate: this.onDeactivate,
          },
        },
        a
      )
    );
  },
  onActivate: function (a) {
    if (this.PanelTest) {
      this.PanelTest.load();
    }
  },
  onDeactivate: function (a) {},
});

// Test panel
SYNO.SDS.OH2.PanelTest = Ext.extend(Ext.FormPanel, {
  constructor: function (a) {
    this.app = a.app;
    SYNO.SDS.OH2.PanelTest.superclass.constructor.call(
      this,
      Ext.apply(
        {
          border: false,
          labelWidth: 125,
          bodyStyle: "padding: 5px 5px 0",
          monitorValid: true,
          items: [
            {
              xtype: "fieldset",
              title: _V("config", "fieldset_test"),
              defaultType: "textfield",
              defaults: {
                anchor: "-20",
              },
            },
          ],
          buttons: [
            {
              text: _T("common", "apply"),
              handler: function () {
                this.getForm().submit();
              },
              scope: this,
            },
          ],
        },
        a
      )
    );
    this.on("beforeaction", function (form, action) {
      this.app.setStatusBusy();
    });
    this.on("actioncomplete", function (form, action) {
      this.app.clearStatusBusy();
      if (action.type == "directsubmit") {
        this.app.setStatusOK({ text: _V("messages", "saved") });
      }
    });
    this.on("actionfailed", function (form, action) {
      this.app.clearStatusBusy();
      if (action.type == "directsubmit") {
        this.app.setStatusError({ clear: true });
        if (action.failureType == Ext.form.Action.SERVER_INVALID) {
          for (field in action.result.myerrors) {
            this.getForm().findField(field).markInvalid();
          }
        }
      } else {
        this.app.setStatusError();
      }
    });
  },
});
