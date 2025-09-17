import 'package:gig_hub/src/Data/app_imports.dart';

class SignUpSheet extends StatefulWidget {
  const SignUpSheet({super.key});

  @override
  State<SignUpSheet> createState() => _SignUpSheetState();
}

class _SignUpSheetState extends State<SignUpSheet> {
  Set<String> selected = {'dj'};
  bool isObscured = true;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (selected.contains('dj')) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) => CreateProfileScreenDJ(
                  email: _emailController.text,
                  pw: _passwordController.text,
                ),
          ),
        );
      } else if (selected.contains('booker')) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) => CreateProfileScreenBooker(
                  email: _emailController.text,
                  pw: _passwordController.text,
                ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Palette.primalBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocale.signUpLowerCase.getString(context),
                style: TextStyle(
                  color: Palette.glazedWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 36),
              SizedBox(
                height: 48,
                width: 270,
                child: LiquidGlass(
                  shape: LiquidRoundedRectangle(
                    borderRadius: Radius.circular(16),
                  ),
                  settings: LiquidGlassSettings(
                    thickness: 30,
                    refractiveIndex: 1.1,
                    chromaticAberration: 1.3,
                  ),
                  child: SegmentedButton<String>(
                    expandedInsets: EdgeInsets.all(2),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<String>(
                        value: 'booker',
                        label: Text("booker", style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment<String>(
                        value: 'dj',
                        label: Text(
                          "    DJ    ",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    selected: selected,
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        selected = newSelection;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Palette.shadowGrey;
                        }
                        return Palette.shadowGrey.o(0.35);
                      }),
                      foregroundColor: WidgetStateProperty.all(
                        Palette.primalBlack,
                      ),
                      textStyle: WidgetStateProperty.resolveWith<TextStyle?>((
                        states,
                      ) {
                        return TextStyle(
                          fontWeight:
                              states.contains(WidgetState.selected)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        );
                      }),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Palette.shadowGrey, width: 2),
                        ),
                      ),
                      padding: WidgetStateProperty.all<EdgeInsets>(
                        const EdgeInsets.symmetric(horizontal: 24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 72),

              TextFormField(
                focusNode: _emailFocusNode,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
                validator: validateEmail,
                autofillHints: [AutofillHints.email],
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                },

                style: TextStyle(color: Palette.glazedWhite),
                decoration: InputDecoration(
                  hintText: AppLocale.email.getString(context),
                  hintStyle: TextStyle(color: Palette.glazedWhite.o(0.7)),
                  prefixIcon: Icon(
                    Icons.email,
                    color: Palette.glazedWhite.o(0.7),
                  ),
                  filled: true,
                  fillColor: Palette.glazedWhite.o(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              TextFormField(
                focusNode: _passwordFocusNode,
                textInputAction: TextInputAction.next,
                controller: _passwordController,
                obscureText: isObscured,
                validator: validatePassword,
                autofillHints: [AutofillHints.password],
                onFieldSubmitted: (_) {
                  FocusScope.of(
                    context,
                  ).requestFocus(_confirmPasswordFocusNode);
                },
                style: TextStyle(color: Palette.glazedWhite),
                decoration: InputDecoration(
                  hintText: AppLocale.pw.getString(context),
                  hintStyle: TextStyle(color: Palette.glazedWhite.o(0.7)),
                  prefixIcon: Icon(
                    Icons.lock,
                    color: Palette.glazedWhite.o(0.7),
                  ),
                  suffixIcon: IconButton(
                    onPressed:
                        () => setState(() {
                          isObscured = !isObscured;
                        }),
                    icon: Icon(
                      isObscured ? Icons.visibility : Icons.visibility_off,
                      color: Palette.concreteGrey,
                    ),
                  ),
                  filled: true,
                  fillColor: Palette.glazedWhite.o(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              TextFormField(
                focusNode: _confirmPasswordFocusNode,
                textInputAction: TextInputAction.done,
                controller: _confirmPasswordController,
                obscureText: isObscured,
                validator:
                    (value) => validateConfirmPassword(
                      value,
                      _passwordController.text,
                    ),
                onFieldSubmitted: (_) {
                  _submitForm();
                },
                style: TextStyle(color: Palette.glazedWhite),
                decoration: InputDecoration(
                  hintText: AppLocale.confirmPw.getString(context),
                  hintStyle: TextStyle(color: Palette.glazedWhite.o(0.7)),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: Palette.glazedWhite.o(0.7),
                  ),
                  filled: true,
                  fillColor: Palette.glazedWhite.o(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 96),
              LiquidGlass(
                shape: LiquidRoundedRectangle(
                  borderRadius: Radius.circular(16),
                ),
                settings: LiquidGlassSettings(
                  thickness: 32,
                  refractiveIndex: 1.1,
                  chromaticAberration: 0.85,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.forgedGold,
                      foregroundColor: Palette.primalBlack,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Palette.concreteGrey.o(0.7),
                          width: 2,
                        ),
                      ),
                    ),
                    onPressed: _submitForm,
                    child: Text(
                      AppLocale.next.getString(context),
                      style: GoogleFonts.sometypeMono(
                        textStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Palette.glazedWhite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }
}

// Validator-Funktionen

String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'please enter your artist or club/event name';
  }
  if (value.trim().length > 24) {
    return 'name is too long';
  }
  return null;
}

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'please enter your email';
  }
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
    return 'enter a valid email';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.length < 6) {
    return 'password needs at least 6 characters';
  }
  if (!RegExp(r"[+*#'_\-.:,;!§\$&/()=?`´><^°\[\]{}]").hasMatch(value)) {
    return 'password needs at least 1 special character';
  }
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  if (value != password) {
    return 'passwords do not match';
  }
  return null;
}
