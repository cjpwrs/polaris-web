<auth>
	<div class="authForm">
		<div class="content">
			<img class="logo" src="img/logo.png"/>
			<form name="authForm" onsubmit={ doLogin }>
				<input type="text" name="username" placeholder="Username">
				<input type="password" name="password" placeholder="Password">
				<input type="submit" value="Login">
			</form>
		</div>
	</div>

	<script>
		doLogin(e) {
			e.preventDefault();
			var form = document.forms["authForm"];
			var username = encodeURIComponent(form.elements["username"].value);
			var password = encodeURIComponent(form.elements["password"].value);
			fetch("/api/auth", {
				method: "POST",
				body: "username=" + username + "&password=" + password,
				headers: {
					"Content-type": "application/x-www-form-urlencoded",
				},
				credentials: 'same-origin',
			})
			.then(function(res) {
				if (res.status == 200) {
					Cookies.set("username", username);
					route("browse", null, true);
				}
			});
		}
	</script>

	<style>

		.authForm {
			height: 100%;
			margin: auto;
			width: 25%;
		}

		.logo {
			width: 100%;
			margin-bottom: 70px;
		}

		.content {
			display: flex;
			flex-flow: column nowrap;
			justify-content: center;
			align-items: stretch;
			height: 90%;
		}

		form {
			display: flex;
			flex-flow: column nowrap;
			justify-content: center;
			align-items: stretch;
		}

		input {
			display: block;
			margin: 5px 0;
			font-size: 1.5rem;
		}

		input[type="submit"] {
			width: 20%;
			margin-top: 15px;
			align-self: flex-end;
			border: none;
			color: #FFF;
			background-color: #44C8F1;
			border-radius: 5px;
			font-size: 1.25rem;
		}

		input[type="text"], input[type="password"] {
			border: 0;
			padding-left: 10px;
			box-sizing: content-box;
			border-bottom: 1px solid #AAA; 
		}
		
	</style>

</auth>