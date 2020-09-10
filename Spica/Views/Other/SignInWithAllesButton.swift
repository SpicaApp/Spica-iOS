//
// Spica for iOS (Spica)
// File created by Lea Baumgart on 21.08.20.
//
// Licensed under the GNU General Public License v3.0
// Copyright © 2020 Lea (Adrian) Baumgart. All rights reserved.
//
// https://github.com/SpicaApp/Spica-iOS
//

import SwiftUI

struct SignInWithAllesButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action, label: {
            Group {
                HStack {
                    Image("Alles Rainbow").resizable().frame(width: 40, height: 40, alignment: .leading).padding([.top, .bottom])
                    Text("Continue with Alles").bold().foregroundColor(.init(UIColor.label))
                }
            }.frame(maxWidth: .infinity).background(Color(UIColor.secondarySystemBackground)) /* .background(Color("Sign in with Alles")) */ .cornerRadius(20)

		})
    }
}

struct SignInWithAllesButton_Previews: PreviewProvider {
    static var previews: some View {
        SignInWithAllesButton {
            //
        }.padding()
        /* SignInWithAllesButton()
         .previewLayout(.fixed(width: 300, height: 70)) */
    }
}